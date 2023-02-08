#include <stdio.h> 
#include <stdlib.h> 
#include <unistd.h> 
#include <string.h> 
#include <signal.h>
#include <time.h>
#include <sys/wait.h> 

#define LEN 100
#define DELAY 2

int p_flag = 0;

void catch_sig(int signum) {
	printf("Proccess %d: catched signal %d\n", getpid(), signum);
	p_flag = 1;
}

int main() {
	//Pipe
	int fd[2];
	if (pipe(fd) == -1) 
	{
        perror("Couldn't pipe.");
		exit(1);
	}
	// Ctrl + Z
	void (*old_handler)(int) = signal(SIGTSTP, catch_sig);

	pid_t child = fork();
	if (child == -1) 
	{
        perror("Couldn't fork.");
		exit(1);
	} 
	else if (child == 0) // Child 
	{
		while (!p_flag) ;
		char msg[LEN];
		close(fd[1]);
		read(fd[0], msg, LEN);	
		printf("Child: read [%s]\n", msg);
		sleep(DELAY);
	} 
	else // Parent
	{
		printf("Parent: pid = %d\n", getpid());
		printf("Child: pid = %d\n", child);
		close(fd[0]);
		char msg[] = "Hello From Parent ";
		write(fd[1], msg, LEN);
		
		printf("Parent: waiting for CTRL+Z signal\n");
		while (!p_flag);
		
		int status;
		pid_t ret = wait(&status);
		
		if (WIFEXITED(status))
			printf("Parent: child %d finished with %d code.\n", ret, WEXITSTATUS(status));
		else if (WIFSIGNALED(status))
			printf("Parent: child %d finished from signal with %d code.\n", ret, WTERMSIG(status));
		else if (WIFSTOPPED(status))
			printf("Parent: child %d finished from signal with %d code.\n", ret, WSTOPSIG(status));	
	}
	
	signal(SIGTSTP, old_handler);
	return 0;
}
