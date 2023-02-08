#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

#define DELAY 4

int main() {
    pid_t child1 = fork();
    
    if (child1 == -1) 
    {
		perror("Can't fork Child 1");
		exit(1);
	} 
    else if (child1 == 0) // Child 1
    {
		printf("Child 1: pid=%d, pidid=%d, groupid=%d\n", (int) getpid(), (int) getppid(), (int) getpgrp());
		sleep(DELAY);
		printf("Child 1: pid=%d, pidid=%d, groupid=%d\n", getpid(), getppid(), getpgrp());
		return 0;
	}
	
	//printf("Parent 111: pid=%d, childpid=%d, groupid=%d\n", getpid(), pid1, getpgrp());
	pid_t child2 = fork();
	if (child2 == -1) 
	{
		perror("Can't fork");
		exit(1);
	} 
	else if (child2 == 0) // Child 2
	{
	    printf("Child 2: pid=%d, pidid=%d, groupid=%d\n", getpid(), getppid(), getpgrp());
		sleep(DELAY);
		printf("Child 2: pid=%d, pidid=%d, groupid=%d\n", getpid(), getppid(), getpgrp());
       	return 0;
	}
	
	// Parent
	printf("Parent: pid=%d, child1=%d, child2=%d, groupid=%d\n", getpid(), child1, child2, getpgrp());
	sleep(1);
	return 0;
}
