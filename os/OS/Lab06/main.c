#include <stdio.h>
#include <stdbool.h>
#include <windows.h>

#define WRITERS_COUNT 3
#define READERS_COUNT 5

#define ITERATIONS_NUMBER 10

#define PAUSE 200 /* ms*/

HANDLE mutex;
HANDLE can_read;
HANDLE can_write;

HANDLE writers[WRITERS_COUNT];
HANDLE readers[READERS_COUNT];

volatile LONG active_readers_count = 0;
bool active_writer = false;

volatile LONG waiting_writers_count = 0;
volatile LONG waiting_readers_count = 0;

int value = 0;

void start_read(void) 
{
	WaitForSingleObject(mutex, INFINITE);

	InterlockedIncrement(&waiting_readers_count);

	if (active_writer || WaitForSingleObject(can_write, 0) == WAIT_OBJECT_0) 
	{
		WaitForSingleObject(can_read, INFINITE);
	}

	InterlockedDecrement(&waiting_readers_count);
	InterlockedIncrement(&active_readers_count);
	
	SetEvent(can_read);
	ReleaseMutex(mutex);
}

void stop_read(void) 
{
	InterlockedDecrement(&active_readers_count);
	if (active_readers_count == 0) 
	{
		SetEvent(can_write);
	}
}

void start_write(void) 
{
	InterlockedIncrement(&waiting_writers_count);
	if (active_writer || active_readers_count > 0) 
	{
		WaitForSingleObject(can_write, INFINITE);
	}

	InterlockedDecrement(&waiting_writers_count);
	active_writer = true;
	ResetEvent(can_write);
}

void stop_write(void) 
{
	active_writer = false;
	
	if (waiting_readers_count > 0) 
	{
		SetEvent(can_read);
	}
	else
	{
		SetEvent(can_write);
	}
}

DWORD WINAPI writer(LPVOID lpParams) 
{
	for (int i = 0; i < ITERATIONS_NUMBER; ++i)
	{
		start_write();

		value++;
		printf("Writer-%d writes value '%d'\n", (int)lpParams, value);

		stop_write();
		Sleep(PAUSE);
	}

	return EXIT_SUCCESS;
}

DWORD WINAPI reader(LPVOID lpParams) 
{
	while (value < WRITERS_COUNT * ITERATIONS_NUMBER)
	{
		start_read();

		printf("\t\t\t\tReader-%d reads value '%d'\n", (int)lpParams, value);

		stop_read();
		Sleep(PAUSE);
	}

	return EXIT_SUCCESS;
}

int createHandles(void) 
{
	if ((mutex = CreateMutex(NULL, FALSE, NULL)) == NULL) 
	{
		perror("CreateMutex");
		return EXIT_FAILURE;
	}

	if ((can_read = CreateEvent(NULL, FALSE, TRUE, NULL)) == NULL) 
	{
		perror("CreateEvent");
		return EXIT_FAILURE;
	}

	if ((can_write = CreateEvent(NULL, TRUE, TRUE, NULL)) == NULL) 
	{
		perror("CreateEvent");
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}

int createThreads(HANDLE* threads, int threads_count, DWORD(*fn_on_thread)(LPVOID)) 
{
	for (int i = 0; i < threads_count; ++i) 
	{
		if ((threads[i] = CreateThread(NULL, 0, fn_on_thread, (LPVOID)i, 0, NULL)) == NULL) 
		{
			perror("CreateThread");
			return EXIT_FAILURE;
		}
	}

	return EXIT_SUCCESS;
}

void closeHandleThreads(HANDLE* threads, int threads_count)
{
	for (int i = 0; i < threads_count; i++) 
	{
		CloseHandle(threads[i]);
	}
}

int main(void) 
{
	setbuf(stdout, NULL);

	int rc = EXIT_SUCCESS;

	if ((rc = createHandles()) != EXIT_SUCCESS || (rc = createThreads(writers, WRITERS_COUNT, writer)) != EXIT_SUCCESS
		|| (rc = createThreads(readers, READERS_COUNT, reader)) != EXIT_SUCCESS) 
	{
		return rc;
	}

	WaitForMultipleObjects(WRITERS_COUNT, writers, TRUE, INFINITE);
	WaitForMultipleObjects(READERS_COUNT, readers, TRUE, INFINITE);

	closeHandleThreads(writers, WRITERS_COUNT);
	closeHandleThreads(readers, READERS_COUNT);
	CloseHandle(mutex);
	CloseHandle(can_read);
	CloseHandle(can_write);

	return rc;
}
