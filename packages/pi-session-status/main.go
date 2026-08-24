package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"syscall"
)

type session struct {
	ID            string `json:"id"`
	PID           int    `json:"pid"`
	SessionID     string `json:"sessionId"`
	Label         string `json:"label"`
	Status        string `json:"status"`
	WindowAddress string `json:"windowAddress"`
	Project       string `json:"project"`
	Revision      any    `json:"revision"`
	Source        string `json:"source"`
}

type response struct {
	Sessions []session `json:"sessions"`
	Error    *string   `json:"error"`
}

var windowAddressPattern = regexp.MustCompile(`^0x[0-9a-fA-F]+$`)

func main() {
	procRoot := environmentOr("PI_SESSIONS_PROC_ROOT", "/proc")
	uid := targetUID()
	stateDir := os.Getenv("PI_SESSIONS_STATE_DIR")
	if stateDir == "" {
		runtimeDir := environmentOr("XDG_RUNTIME_DIR", filepath.Join("/run/user", strconv.FormatUint(uint64(uid), 10)))
		stateDir = filepath.Join(runtimeDir, "pi-session-status")
	}

	sessions, err := collectSessions(procRoot, stateDir, uid)
	if err != nil {
		message := "Cannot read the process table"
		writeResponse(response{Sessions: []session{}, Error: &message})
		return
	}

	sort.Slice(sessions, func(i, j int) bool {
		left, right := sessions[i], sessions[j]
		if statusRank(left.Status) != statusRank(right.Status) {
			return statusRank(left.Status) < statusRank(right.Status)
		}
		if left.Label != right.Label {
			return left.Label < right.Label
		}
		return left.PID < right.PID
	})
	writeResponse(response{Sessions: sessions})
}

func collectSessions(procPath, statePath string, uid uint32) ([]session, error) {
	directory, err := os.Open(procPath)
	if err != nil {
		return nil, err
	}
	defer directory.Close()

	entries, err := directory.ReadDir(-1)
	if err != nil {
		return nil, err
	}

	sessions := make([]session, 0, 8)
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		pid, err := strconv.Atoi(entry.Name())
		if err != nil || pid < 1 {
			continue
		}
		pidName := strconv.Itoa(pid)

		processDir := filepath.Join(procPath, pidName)
		command, err := os.ReadFile(filepath.Join(processDir, "comm"))
		if err != nil || strings.TrimSpace(string(command)) != "pi" {
			continue
		}

		info, err := entry.Info()
		if err != nil || !ownedBy(info, uid) {
			continue
		}

		project := processProject(processDir, pid)
		record, err := os.ReadFile(filepath.Join(statePath, pidName+".json"))
		if err == nil {
			if instrumented, ok := parseRecord(record, pid, project); ok {
				sessions = append(sessions, instrumented)
				continue
			}
		}
		sessions = append(sessions, unknownSession(pid, project))
	}
	return sessions, nil
}

func ownedBy(info os.FileInfo, uid uint32) bool {
	stat, ok := info.Sys().(*syscall.Stat_t)
	return ok && stat.Uid == uid
}

func processProject(processDir string, pid int) string {
	cwd, err := os.Readlink(filepath.Join(processDir, "cwd"))
	if err == nil {
		if project := filepath.Base(cwd); project != "" && project != "." && project != string(filepath.Separator) {
			return project
		}
	}
	return fmt.Sprintf("Pi %d", pid)
}

func parseRecord(data []byte, pid int, fallbackProject string) (session, bool) {
	record := make(map[string]any)
	if json.Unmarshal(data, &record) != nil {
		return session{}, false
	}

	version, versionOK := record["version"].(float64)
	recordPID, pidOK := record["pid"].(float64)
	sessionID, sessionIDOK := nonemptyString(record["sessionId"])
	status, statusOK := nonemptyString(record["status"])
	if !versionOK || version != 1 || !pidOK || recordPID != float64(pid) || !sessionIDOK || !statusOK || !knownStatus(status) {
		return session{}, false
	}

	project := fallbackProject
	if value, ok := nonemptyString(record["project"]); ok {
		project = value
	}
	label := project
	if value, ok := nonemptyString(record["label"]); ok {
		label = value
	}
	windowAddress := ""
	if value, ok := nonemptyString(record["windowAddress"]); ok && windowAddressPattern.MatchString(value) {
		windowAddress = strings.ToLower(value)
	}
	revision := any(0)
	if value, ok := record["revision"].(float64); ok {
		revision = value
	}

	return session{
		ID:            fmt.Sprintf("pid:%d", pid),
		PID:           pid,
		SessionID:     sessionID,
		Label:         label,
		Status:        status,
		WindowAddress: windowAddress,
		Project:       project,
		Revision:      revision,
		Source:        "extension",
	}, true
}

func unknownSession(pid int, project string) session {
	return session{
		ID:        fmt.Sprintf("pid:%d", pid),
		PID:       pid,
		SessionID: "",
		Label:     project,
		Status:    "unknown",
		Project:   project,
		Revision:  0,
		Source:    "process",
	}
}

func nonemptyString(value any) (string, bool) {
	text, ok := value.(string)
	return text, ok && text != ""
}

func knownStatus(status string) bool {
	return status == "blocked" || status == "done" || status == "working" || status == "idle"
}

func statusRank(status string) int {
	switch status {
	case "blocked":
		return 0
	case "done":
		return 1
	case "working":
		return 2
	case "idle":
		return 3
	default:
		return 4
	}
}

func targetUID() uint32 {
	configured := os.Getenv("PI_SESSIONS_UID")
	if configured == "" {
		return uint32(os.Geteuid())
	}
	value, err := strconv.ParseUint(configured, 10, 32)
	if err != nil {
		return ^uint32(0)
	}
	return uint32(value)
}

func environmentOr(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

func writeResponse(value response) {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(value); err != nil {
		os.Exit(1)
	}
}
