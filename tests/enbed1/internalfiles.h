
#include <stddef.h>

struct Buffer {
	const char* data;
	size_t size;
};

//enbed ./textfile.txt
extern struct Buffer internal_file;
