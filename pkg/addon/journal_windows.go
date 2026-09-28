package addon

import (
	"golang.org/x/sys/windows"
	"os"
)

// Closing the file releases this nonblocking, exclusive byte-range lock.
func lockJournalFile(f *os.File) error {
	return windows.LockFileEx(windows.Handle(f.Fd()), windows.LOCKFILE_EXCLUSIVE_LOCK|windows.LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &windows.Overlapped{})
}

// Windows cannot flush a directory handle with os.File.Sync. atomicJSON flushes
// and closes the temporary file before os.Rename replaces the journal.
func syncJournalDirectory(_ string) error { return nil }
