// Bookworm cdebconf GTK, newt and text frontends obtain their visible strings
// through this function. Extend only the error body, leaving recovery controls
// and the frontend's normal translation and substitution handling intact.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct frontend;
struct question;
typedef char *(*field_reader)(struct frontend *, const struct question *, const char *, const char *);
extern char *question_get_raw_field(const struct question *, const char *, const char *);
extern const char *question_get_tag(const struct question *);

char *question_get_field(struct frontend *fe, const struct question *q,
                         const char *lang, const char *field)
{
    static field_reader original;
    if (!original)
        original = (field_reader)dlsym(RTLD_NEXT, "question_get_field");
    char *body = original(fe, q, lang, field);
    if (strcmp(field, "extended_description") != 0)
        return body;

    char *type = question_get_raw_field(q, "C", "type");
    const char *tag = question_get_tag(q);
    int show_log = strcmp(type, "error") == 0 || strcmp(tag, "camerawall/retry-target") == 0;
    free(type);
    if (!show_log)
        return body;

    FILE *pipe = popen("/bin/sh /camerawall/install-log.sh", "r");
    if (!pipe)
        return body;
    char *log = NULL;
    size_t capacity = 0;
    // The shell formatter emits text without NUL bytes. Read through EOF.
    ssize_t length = getdelim(&log, &capacity, '\0', pipe);
    pclose(pipe); // cdebconf may already have reaped the child.
    char *with_log = NULL;
    if (length > 0 && asprintf(&with_log, "%s\n\n%s", body, log) < 0)
        with_log = NULL;
    free(log);
    if (!with_log)
        return body;
    free(body);
    return with_log;
}
