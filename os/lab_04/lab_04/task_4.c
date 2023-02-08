#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>

#define LEN 100

int main() 
{
	// Pipe
	int fd[2];
	
	if (pipe(fd) == -1)
	{
		perror("Couldn't pipe.");
		exit(1);
	}

	// Child 1
	pid_t child1 = fork();
	
	if (child1 == -1)
	{
		perror("Couldn't fork.");
		exit(1);
	}	
	
	else if (child1 == 0)
	{
		close(fd[0]);
		char msg1[] = "Hello From Child 1 ";
		write(fd[1], msg1, LEN);
		printf("Child 1: writen [%s] to Pipe\n", msg1);
		exit(0);
	}

	// Child 2
	int child2 = fork();
	
	if (child2 == -1)
	{
		perror("Couldn't fork.");
		exit(1);
	}

	else if (child2 == 0)
	{
		close(fd[0]);
		char msg2[] = "Hello From Child 2 ";
		write(fd[1], msg2, LEN);
		printf("Child 2: writen [%s] to Pipe\n", msg2);
		exit(0);
	}

	//Parents
	int status1, status2;
	pid_t ret1 = wait(&status1);
	pid_t ret2 = wait(&status2);
	
	close(fd[1]);
	char msg1[LEN];
	read(fd[0], msg1, LEN);
	char msg2[LEN];
	read(fd[0], msg2, LEN);

	printf("Parent: read from Pipe [%s%s]\n", msg1, msg2);
	
	if (WIFEXITED(status1))
		printf("Parent: child %d finished with %d code.\n", ret1, WEXITSTATUS(status1));
	else if (WIFSIGNALED(status1))
		printf("Parent: child %d finished from signal with %d code.\n", ret1, WTERMSIG(status1));
	else if (WIFSTOPPED(status1))
		printf("Parent: child %d finished from signal with %d code.\n", ret1, WSTOPSIG(status1));

	if (WIFEXITED(status2))
		printf("Parent: child %d finished with %d code.\n", ret2, WEXITSTATUS(status2));
	else if (WIFSIGNALED(status2))
		printf("Parent: child %d finished from signal with %d code.\n", ret2, WTERMSIG(status2));
	else if (WIFSTOPPED(status2))
		printf("Parent: child %d finished from signal with %d code.\n", ret2, WSTOPSIG(status2));

	return 0;
}
