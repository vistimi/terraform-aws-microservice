package util

import (
	"fmt"
	"regexp"
	"testing"

	"github.com/google/go-cmp/cmp"
)

func Equal[E, A interface{ string | int }](t *testing.T, expected E, actual A) {
	if !cmp.Equal(expected, actual) {
		t.Errorf("\nexpected:\n%v\nactual:\n%vdiff:\n%v", expected, actual, cmp.Diff(expected, actual))
	}
}

func Finds(t *testing.T, needles []string, sources []string) {
	for _, source := range sources {
		found := false
		for _, needle := range needles {
			match, _ := regexp.MatchString(needle, source)
			if match {
				found = match
				break
			}
		}

		if !found {
			t.Fatalf("Could not find in regexp\nsource:\n%s\nneedles:\n%s", source, needles)
		}
	}
}

func Find(t *testing.T, needle string, source string) {
	if err := FindE(needle, source); err != nil {
		t.Fatal(err)
	}
}

func FindE(needle string, source string) error {
	if match, _ := regexp.MatchString(needle, source); !match {
		return fmt.Errorf("could not find in regexp\nsource:\n%s\nneedle:\n%s", source, needle)
	}
	return nil
}
