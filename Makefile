make:
	g++ -g -c get_pe.C -o get_pe.o `root-config --cflags --glibs`
	g++ get_pe.o libremoll.so -o get_pe `root-config --cflags --glibs` -L. -lremoll -Wl,-R.
	rm get_pe.o
