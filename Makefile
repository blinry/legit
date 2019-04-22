%: %.ll
	clang -O3 -o $@ $<
