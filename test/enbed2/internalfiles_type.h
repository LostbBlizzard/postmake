#include <stddef.h> //size_t

struct InternalFileBuffer {
	const char* data;
	size_t size;
};
struct InternalFile {
	const char* filename;
	InternalFileBuffer Data;
};
struct InternalFileList {
	const InternalFile* data;
	size_t size;
};
