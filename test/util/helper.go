package util

func Nil[K any]() any {
	return nil
}

func ObjNil[K any](obj *K, objMap map[string]any, key string) map[string]any {
	if obj != nil {
		objMap[key] = *obj
	}
	return objMap
}

func Ptr[K any](m K) *K {
	return &m
}

func Value[K any](m *K, def ...K) K {
	if m == nil {
		if len(def) == 1 {
			return def[0]
		}
		var empty K
		return empty
	}
	return *m
}

func ValueNil[K any](m *K) any {
	if m == nil {
		return nil
	}
	return *m
}

func Filter[T any](ss []T, test func(T) bool) (ret []T) {
	for _, s := range ss {
		if test(s) {
			ret = append(ret, s)
		}
	}
	return
}

func Reduce[T, R any](ss []T, test func(T) R) (ret []R) {
	for _, s := range ss {
		ret = append(ret, test(s))
	}
	return
}
