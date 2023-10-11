package util

func Format(separator string, names ...string) (s string) {
	names = Filter(names, func(n string) bool { return n != "" })
	if len(names) == 0 {
		return ""
	}
	s = names[0]
	for _, name := range names[1:] {
		s = s + separator + name
	}
	return
}

func Appends(separator string, pre string, names []string) []string {
	names = Filter(names, func(n string) bool { return n != "" })
	for i, name := range names {
		names[i] = pre + separator + name
	}
	return names
}
func Preppends(separator string, names []string, post string) []string {
	names = Filter(names, func(n string) bool { return n != "" })
	for i, name := range names {
		names[i] = name + separator + post
	}
	return names
}
