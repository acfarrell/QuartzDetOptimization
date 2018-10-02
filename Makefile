make:
g++ -g -c get_pe.C -o get_pe.o `root-config --cflags --glibs`
g++ get_pe.o libremoll.so -o rad_dose `root-config --cflags --glibs` -L. -lremoll -Wl,-R.
rm get_pe.o
