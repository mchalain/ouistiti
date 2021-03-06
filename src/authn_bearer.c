/*****************************************************************************
 * authn_bearer.c: Basic Authentication mode
 * this file is part of https://github.com/ouistiti-project/ouistiti
 *****************************************************************************
 * Copyright (C) 2016-2017
 *
 * Authors: Marc Chalain <marc.chalain@gmail.com>
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

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/stat.h>

#include "httpserver/httpserver.h"
#include "httpserver/utils.h"
#include "httpserver/log.h"
#include "mod_auth.h"
#include "authn_bearer.h"

#define auth_dbg(...)

typedef struct authn_bearer_s authn_bearer_t;
struct authn_bearer_s
{
	authn_bearer_config_t *config;
	const authn_t *authn;
	authz_t *authz;
	http_client_t *clt;
};

#ifdef FILE_CONFIG
void *authn_bearer_config(const config_setting_t *configauth)
{
	authn_bearer_config_t *authn_config = NULL;

	authn_config = calloc(1, sizeof(*authn_config));
	config_setting_lookup_string(configauth, "realm", (const char **)&authn_config->realm);
	return authn_config;
}
#endif

static void *authn_bearer_create(const authn_t *authn, authz_t *authz, void *arg)
{
	authn_bearer_t *mod = calloc(1, sizeof(*mod));
	mod->authn = authn;
	mod->authz = authz;
	mod->config = (authn_bearer_config_t *)arg;
	if (mod->config->realm == NULL)
		mod->config->realm = httpserver_INFO(authn->server, "host");

	return mod;
}

static int authn_bearer_challenge(void *arg, http_message_t *request, http_message_t *response)
{
	int ret = ECONTINUE;
	const authn_bearer_t *mod = (authn_bearer_t *)arg;
	const authn_bearer_config_t *config = mod->config;

	httpmessage_addheader(response, str_authenticate, "Bearer realm=\"");
	httpmessage_appendheader(response, str_authenticate, config->realm, "\"", NULL);
	return ret;
}

static const char *authn_bearer_check(void *arg, const char *method, const char *uri, const char *string)
{
	const authn_bearer_t *mod = (authn_bearer_t *)arg;
	(void) method;
	(void) uri;

	if (!strncmp(string, "Bearer ", 7))
		string += 7;
	const char *user = NULL;
	const char *data = string;
	const char *sign = strrchr(string, '.');
	if (sign != NULL)
	{
		size_t datalen = sign - data;
		sign++;
		if (authn_checksignature(mod->authn->config->secret, data, datalen, sign, strlen(sign)) == ESUCCESS)
		{
			user = mod->authz->rules->check(mod->authz->ctx, NULL, NULL, string);
		}
	}
	return user;
}

static void authn_bearer_destroy(void *arg)
{
	authn_bearer_t *mod = (authn_bearer_t *)arg;
	free(mod);
}

authn_rules_t authn_bearer_rules =
{
	.create = &authn_bearer_create,
	.challenge = &authn_bearer_challenge,
	.check = &authn_bearer_check,
	.destroy = &authn_bearer_destroy,
};
