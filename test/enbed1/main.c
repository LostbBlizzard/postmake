#include <stdio.h>
#include "./internalfiles.h"

int main() {
	printf("Test: %.*s",(int)internal_file.size,internal_file.data);
}
