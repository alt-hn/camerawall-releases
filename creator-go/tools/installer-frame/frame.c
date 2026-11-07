/* GTK 2 module for the Debian Installer's full-screen window.
 * Only the public GTK/GDK/GLib ABI below is needed to cross-build it.
 */
typedef unsigned long GType;
typedef struct GValue GValue;
typedef struct GSignalInvocationHint GSignalInvocationHint;
typedef struct GtkWidget GtkWidget;
typedef struct GdkScreen GdkScreen;

extern GType gtk_widget_get_type(void);
extern GType gtk_window_get_type(void);
extern void *g_type_class_ref(GType type);
extern void g_type_class_unref(void *klass);
extern int g_type_check_instance_is_a(void *instance, GType type);
extern unsigned g_signal_lookup(const char *name, GType type);
extern unsigned long g_signal_add_emission_hook(unsigned signal, unsigned detail,
    int (*hook)(GSignalInvocationHint *, unsigned, const GValue *, void *),
    void *data, void (*destroy)(void *));
extern void *g_value_get_object(const GValue *value);
extern void gtk_widget_get_size_request(GtkWidget *widget, int *width, int *height);
extern GdkScreen *gtk_widget_get_screen(GtkWidget *widget);
extern int gdk_screen_get_width(GdkScreen *screen);
extern int gdk_screen_get_height(GdkScreen *screen);
extern GtkWidget *gtk_bin_get_child(void *bin);
extern GtkWidget *gtk_alignment_new(float xalign, float yalign, float xscale, float yscale);
extern void gtk_alignment_set_padding(void *alignment, unsigned top, unsigned bottom,
                                      unsigned left, unsigned right);
extern void gtk_container_add(void *container, GtkWidget *child);
extern void gtk_container_remove(void *container, GtkWidget *child);
extern void gtk_widget_show(GtkWidget *widget);
extern void *g_object_ref(void *object);
extern void g_object_unref(void *object);

static int frame_installer(GSignalInvocationHint *hint, unsigned count,
                          const GValue *values, void *data)
{
    GtkWidget *widget = g_value_get_object(values);
    if (!g_type_check_instance_is_a(widget, gtk_window_get_type()))
        return 1;

    /* cdebconf requests the screen dimensions for its main window only. */
    int width, height;
    gtk_widget_get_size_request(widget, &width, &height);
    GdkScreen *screen = gtk_widget_get_screen(widget);
    if (width != gdk_screen_get_width(screen) || height != gdk_screen_get_height(screen))
        return 1;

    GtkWidget *content = gtk_bin_get_child(widget);
    if (!content)
        return 1;

    /* The framebuffer may report 1024x768 while the panel only shows the
     * top-left 1024x600. Reserve 16 pixels on every visible edge. Keep the
     * window fullscreen so the installer retains keyboard and mouse handling. */
    const int margin = 16;
    const int safe_width = width < 1024 ? width : 1024;
    const int safe_height = height < 600 ? height : 600;
    GtkWidget *viewport = gtk_alignment_new(0, 0, 1, 1);
    gtk_alignment_set_padding(viewport, margin, height - safe_height + margin,
                             margin, width - safe_width + margin);
    g_object_ref(content);
    gtk_container_remove(widget, content);
    gtk_container_add(viewport, content);
    gtk_container_add(widget, viewport);
    g_object_unref(content);
    gtk_widget_show(viewport);
    return 0; /* Remove the hook after finding the installer window. */
}

void gtk_module_init(int *argc, char ***argv)
{
    GType type = gtk_widget_get_type();
    void *klass = g_type_class_ref(type);
    g_signal_add_emission_hook(g_signal_lookup("show", type), 0, frame_installer, 0, 0);
    g_type_class_unref(klass);
}
