package addon

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestJournalLockExclusiveAndReleased(t *testing.T) {
	path := filepath.Join(t.TempDir(), "journal.lock")
	first, err := lockFile(path)
	if err != nil {
		t.Fatal(err)
	}
	defer first.Close()
	if second, err := lockFile(path); err == nil {
		second.Close()
		t.Fatal("two lifecycle owners acquired the same journal")
	}
	if err := first.Close(); err != nil {
		t.Fatal(err)
	}
	next, err := lockFile(path)
	if err != nil {
		t.Fatalf("closed owner kept its lock: %v", err)
	}
	next.Close()
}

func TestJournalReplacement(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state.json")
	for _, value := range []int{1, 2} {
		if err := atomicJSON(path, map[string]int{"generation": value}); err != nil {
			t.Fatal(err)
		}
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		var got map[string]int
		if err := json.Unmarshal(data, &got); err != nil {
			t.Fatal(err)
		}
		if got["generation"] != value {
			t.Fatalf("replacement journal = %v", got)
		}
	}
}
