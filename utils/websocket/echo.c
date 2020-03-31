/*****************************************************************************
 * websocket_echo.c: Simple echo server
 *****************************************************************************
 * Copyright (C) 2016-2017
 *
 * Authors: Marc Chalain <marc.chalain@gmail.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject
 * to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *****************************************************************************/
#define _XOPEN_SOURCE 700

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <pwd.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sched.h>
#include <sys/stat.h>

#define err(format, ...) fprintf(stderr, "\x1B[31m"format"\x1B[0m\n",  ##__VA_ARGS__)
#define warn(format, ...) fprintf(stderr, "\x1B[35m"format"\x1B[0m\n",  ##__VA_ARGS__)
#ifdef DEBUG
#define dbg(format, ...) fprintf(stderr, "\x1B[32m"format"\x1B[0m\n",  ##__VA_ARGS__)
#else
#define dbg(...)
#endif

#define TEST 1
#define DAEMON 2

static int mode = 0;

typedef int (*server_t)(int *psock);

int echo(int *psock)
{
	int sock = *psock;
	int ret = 0;

	while (sock > 0)
	{
		fd_set rfds;
		FD_ZERO(&rfds);
		FD_SET(sock, &rfds);

		ret = select(sock + 1, &rfds, NULL, NULL, NULL);
		if (ret > 0 && FD_ISSET(sock, &rfds))
		{
			char buffer[256];
			ret = recv(sock, buffer, 256, MSG_NOSIGNAL);
			if (ret > 0)
			{
				printf("echo: receive %d %s\n", ret, buffer);
				char *out = buffer;
				ret = strlen(out);
				ret = send(sock, out, ret, MSG_DONTWAIT | MSG_NOSIGNAL);
				if (mode & TEST)
				{
					char ping[] = { 0x8A, 0x00};
					ret = send(sock, ping, sizeof(ping), MSG_DONTWAIT | MSG_NOSIGNAL);
					char goodbye[] = { 0x88, 0x02, 0x03, 0xEA};
					ret = send(sock, goodbye, sizeof(goodbye), MSG_DONTWAIT | MSG_NOSIGNAL);
					ret = 0;
				}
			}
			if (ret <= 0 && errno != EAGAIN)
			{
				if (ret == -1)
					printf("echo: close %s\n", strerror(errno));
				close(sock);
				sock = -1;
			}
		}
	}
	return ret;
}

void help(char **argv)
{
	fprintf(stderr, "%s [-R <socket directory>] [-m <nb max clients>] [-u <user>][ -h]\n", argv[0]);
}

#ifndef PTHREAD
int start(server_t server, int newsock)
{
	if (fork() == 0)
	{
		printf("run\n");
		server(&newsock);
		exit(0);
	}
	sched_yield();
	sched_yield();
	usleep(50);
	printf("close\n");
	close(newsock);
	return 0;
}
#else
#include <pthread.h>
typedef void *(*start_routine_t)(void*);
int start(server_t server, int newsock)
{
	pthread_t thread;
	pthread_create(&thread, NULL, (start_routine_t)server, (void *)&newsock);
}
#endif

const char *str_username = "apache";
#ifndef SOCKDOMAIN
#define SOCKDOMAIN AF_UNIX
#endif
#ifndef SOCKPROTOCOL
#define SOCKPROTOCOL 0
#endif

int main(int argc, char **argv)
{
	int ret = -1;
	int sock;
	char *root = "/var/run/ouistiti";
	char *proto = "echo";
	int maxclients = 50;
	const char *username = str_username;

	setbuf(stdout, NULL);
	setbuf(stderr, NULL);

	int opt;
	do
	{
		opt = getopt(argc, argv, "u:n:R:m:thD");
		switch (opt)
		{
			case 'R':
				root = optarg;
			break;
			case 'h':
				help(argv);
			return -1;
			case 'm':
				maxclients = atoi(optarg);
			break;
			case 'u':
				username = optarg;
			break;
			case 'n':
				proto = optarg;
			break;
			case 't':
				mode |= TEST;
			break;
			case 'D':
				mode |= DAEMON;
			break;
		}
	} while(opt != -1);


	printf("echo: access\n");
	ret = access(root, R_OK|W_OK|X_OK);
	printf(" %d %s\n", ret, strerror(errno));
	if (ret < 0)
	{
		printf("echo: mkdir\n");
		ret = mkdir(root, 0777);
		printf(" %d %s\n", ret, strerror(errno));
		if (ret)
		{
			err("access %s error %s", root, strerror(errno));
			return -1;
		}
		chmod(root, 0777);
	}

	printf("echo: getuid\n");
	ret = getuid();
	printf(" %d %s\n", ret, strerror(errno));
	if (ret == 0)
	{
		struct passwd *user = NULL;
		user = getpwnam(username);
		if (user != NULL)
		{
			if (setegid(user->pw_gid) < 0)
				warn("not enought rights to change group");
			if (seteuid(user->pw_uid) < 0)
				warn("not enought rights to change user");
		}
		else
			warn("user not found");
	}

	sock = socket(SOCKDOMAIN, SOCK_STREAM, SOCKPROTOCOL);
	if (sock > 0)
	{
		struct sockaddr_un addr;
		memset(&addr, 0, sizeof(struct sockaddr_un));
		addr.sun_family = AF_UNIX;
		snprintf(addr.sun_path, sizeof(addr.sun_path) - 1, "%s/%s", root, proto);

		printf("echo: unlink %s\n", addr.sun_path);
		ret = access(addr.sun_path, R_OK);
		if (ret)
			ret = unlink(addr.sun_path);
		printf(" %d %s\n", ret, strerror(errno));

		printf("echo: bind %s\n", addr.sun_path);
		ret = bind(sock, (struct sockaddr *) &addr, sizeof(addr));
		printf(" %d %s\n", ret, strerror(errno));
		if (ret == 0)
		{
			chmod(addr.sun_path, 0777);
			printf("echo: listen\n");
			ret = listen(sock, maxclients);
			printf(" %d %s\n", ret, strerror(errno));
		}
		if ((mode & DAEMON) && (fork() != 0))
		{
			printf("echo: daemonize\n");
			sched_yield();
			return 0;
		}
		printf("echo: start\n");
		if (ret == 0)
		{
			int newsock = 0;
			printf("echo: main loop\n");
			do
			{
				struct sockaddr_in addr;
				int addrsize = sizeof(addr);
				printf("echo: wait\n");
				//newsock = accept(sock, (struct sockaddr *)&addr, &addrsize);
				//printf("echo: new connection from %s\n", inet_ntoa(addr.sin_addr));
				newsock = accept(sock, NULL, NULL);
				printf("echo: new connection \n");
				if (newsock > 0)
				{
					start(echo, newsock);
				}
			} while(newsock > 0);
		}
		close(sock);
	}
	if (ret)
	{
		printf("echo: error %s\n", strerror(errno));
	}
	return ret;
}
