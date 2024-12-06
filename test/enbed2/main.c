#include <stdio.h>
#include "./internalfiles.h"

int main() {

	for (size_t i = 0; i < internal_files.size; i++) {
		const struct InternalFile* item = &internal_files.data[i];
	
		printf("%.*s",(int)item->Data.size,item->Data.data);
	}
}
