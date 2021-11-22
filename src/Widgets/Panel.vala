/*
 * Copyright 2011-2020 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 */

public class Wingpanel.Widgets.Panel : Gtk.EventBox {
    public Services.PopoverManager popover_manager { get; construct; }

    private IndicatorMenuBar right_menubar;
    private Gtk.MenuBar left_menubar;
    private Gtk.MenuBar center_menubar;
    private Gtk.Box     right_box;

    private unowned Gtk.StyleContext style_context;
    private Gtk.CssProvider? style_provider = null;

    private static Gtk.CssProvider resource_provider;
    
    private Gtk.Grid na_grid = null;

    public Panel (Services.PopoverManager popover_manager) {
        Object (popover_manager : popover_manager);
    }

    static construct {
        resource_provider = new Gtk.CssProvider ();
        resource_provider.load_from_resource ("io/elementary/wingpanel/panel.css");
    }

    construct {
        height_request = 30;
        hexpand = true;
        vexpand = true;
        valign = Gtk.Align.START;

        left_menubar = new Gtk.MenuBar () {
            can_focus = true,
            halign = Gtk.Align.START
        };
        left_menubar.get_style_context ().add_provider (resource_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        center_menubar = new Gtk.MenuBar () {
            can_focus = true
        };
        center_menubar.get_style_context ().add_provider (resource_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        right_menubar = new IndicatorMenuBar () {
            can_focus = true,
            halign = Gtk.Align.END
        };
        right_menubar.get_style_context ().add_provider (resource_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        
        right_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6) {
            hexpand = false,
            halign = Gtk.Align.END
        };
        
        na_grid = Gtkx11Tray.get_systray(Gtk.Orientation.HORIZONTAL);
        na_grid.hexpand = false;
        na_grid.halign = Gtk.Align.END;
        na_grid.column_spacing = 15;
        
        right_box.add (na_grid);
        right_box.add (right_menubar);
        
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                
        box.pack_start (left_menubar);
        box.set_center_widget (center_menubar);
        box.pack_end (right_box);

        add (box);

        unowned IndicatorManager indicator_manager = IndicatorManager.get_default ();
        indicator_manager.indicator_added.connect (add_indicator);
        indicator_manager.indicator_removed.connect (remove_indicator);

        indicator_manager.get_indicators ().@foreach ((indicator) => {
            add_indicator (indicator);

            return true;
        });

        style_context = get_style_context ();
        style_context.add_class (StyleClass.PANEL);
        style_context.add_provider (resource_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        Services.BackgroundManager.get_default ().background_state_changed.connect (update_background);

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });
    }

    public override bool button_press_event (Gdk.EventButton event) {
        if (event.button != Gdk.BUTTON_PRIMARY) {
            return Gdk.EVENT_PROPAGATE;
        }

        var window = get_window ();
        if (window == null) {
            return Gdk.EVENT_PROPAGATE;
        }

        // Grabbing with touchscreen on X does not work unfortunately
        if (event.device.get_source () == Gdk.InputSource.TOUCHSCREEN) {
            return Gdk.EVENT_PROPAGATE;
        }

        uint32 time = event.time;

        window.get_display ().get_default_seat ().ungrab ();

        Gdk.ModifierType state;
        event.get_state (out state);

        popover_manager.close ();

        var scale_factor = this.get_scale_factor ();
        var x = (int)event.x_root * scale_factor;
        var y = (int)event.y_root * scale_factor;

        var background_manager = Services.BackgroundManager.get_default ();
        return background_manager.begin_grab_focused_window (x, y, (int)event.button, time, state);
    }

    public void cycle (bool forward) {
        var current = popover_manager.current_indicator;
        if (current == null) {
            return;
        }

        IndicatorEntry? sibling;
        if (forward) {
            sibling = get_next_sibling (current);
        } else {
            sibling = get_previous_sibling (current);
        }

        if (sibling != null) {
            popover_manager.current_indicator = sibling;
        }
    }

    private IndicatorEntry? get_next_sibling (IndicatorEntry current) {
        IndicatorEntry? sibling = null;

        switch (current.base_indicator.code_name) {
            case Indicator.APP_LAUNCHER:
                var children = left_menubar.get_children ();
                int index = children.index (current);
                if (index == -1) {
                    break;
                } else if (index < children.length () - 1) { // Has more than one indicator in the left menubar
                    sibling = children.nth_data (index + 1) as IndicatorEntry;
                } else { // No more indicators on the left
                    var center_children = center_menubar.get_children ();
                    if (center_children.length () > 0) {
                        sibling = center_children.first ().data as IndicatorEntry;
                    }
                }

                break;
            case Indicator.DATETIME:
                var children = center_menubar.get_children ();
                int index = children.index (current);
                if (index == -1) {
                    break;
                } else if (index < children.length () - 1) { // Has more than one indicator in the center menubar
                    sibling = children.nth_data (index + 1) as IndicatorEntry;
                } else { // No more indicators on the center
                    var right_children = right_menubar.get_children ();
                    if (right_children.length () > 0) {
                        sibling = right_children.first ().data as IndicatorEntry;
                    }
                }

                break;
            default:
                var children = right_menubar.get_children ();
                int index = children.index (current);
                if (index == -1) {
                    break;
                } else if (index < children.length () - 1) { // Has more than one indicator in the right menubar
                    sibling = children.nth_data (index + 1) as IndicatorEntry;
                } else { // No more indicators on the right
                    var left_children = left_menubar.get_children ();
                    if (left_children.length () > 0) {
                        sibling = left_children.first ().data as IndicatorEntry;
                    }
                }

                break;
        }

        return sibling;
    }

    private IndicatorEntry? get_previous_sibling (IndicatorEntry current) {
        IndicatorEntry? sibling = null;

        switch (current.base_indicator.code_name) {
            case Indicator.APP_LAUNCHER:
                var children = left_menubar.get_children ();
                int index = children.index (current);
                if (index == -1) {
                    break;
                } else if (index != 0) { // Is not the first indicator in the left menubar
                    sibling = children.nth_data (index - 1) as IndicatorEntry;
                } else { // No more indicators on the left
                    var right_children = right_menubar.get_children ();
                    if (right_children.length () > 0) {
                        sibling = right_children.last ().data as IndicatorEntry;
                    }
                }

                break;
            case Indicator.DATETIME:
                var children = center_menubar.get_children ();
                int index = children.index (current);
                if (index == -1) {
                    break;
                } else if (index != 0) { // Is not the first indicator in the center menubar
                    sibling = children.nth_data (index - 1) as IndicatorEntry;
                } else { // No more indicators on the center
                    var left_children = left_menubar.get_children ();
                    if (left_children.length () > 0) {
                        sibling = left_children.last ().data as IndicatorEntry;
                    }
                }

                break;
            default:
                var children = right_menubar.get_children ();
                int index = children.index (current);
                if (index == -1) {
                    break;
                } else if (index != 0) { // Is not the first indicator in the right menubar
                    sibling = children.nth_data (index - 1) as IndicatorEntry;
                } else { // No more indicators on the right
                    var center_children = center_menubar.get_children ();
                    if (center_children.length () > 0) {
                        sibling = center_children.last ().data as IndicatorEntry;
                    }
                }

                break;
        }

        return sibling;
    }

    private void add_indicator (Indicator indicator) {
        var indicator_entry = new IndicatorEntry (indicator, popover_manager);

        switch (indicator.code_name) {
            case Indicator.APP_LAUNCHER:
                indicator_entry.set_transition_type (Gtk.RevealerTransitionType.SLIDE_RIGHT);
                left_menubar.add (indicator_entry);
                break;
            //case Indicator.DATETIME:
            //    indicator_entry.set_transition_type (Gtk.RevealerTransitionType.SLIDE_DOWN);
            //    center_menubar.add (indicator_entry);
            //    break;
            default:
                indicator_entry.set_transition_type (Gtk.RevealerTransitionType.SLIDE_LEFT);
                right_menubar.insert_sorted (indicator_entry);
                break;
        }

        indicator_entry.show_all ();
    }

    private void remove_indicator (Indicator indicator) {
        remove_indicator_from_container (left_menubar, indicator);
        remove_indicator_from_container (center_menubar, indicator);
        remove_indicator_from_container (right_menubar, indicator);
    }

    private void remove_indicator_from_container (Gtk.Container container, Indicator indicator) {
        foreach (unowned Gtk.Widget child in container.get_children ()) {
            unowned IndicatorEntry? entry = (child as IndicatorEntry);

            if (entry != null && entry.base_indicator == indicator) {
                container.remove (child);

                return;
            }
        }
    }

    private void update_background (Services.BackgroundState state, uint animation_duration) {
        if (style_provider == null) {
            style_provider = new Gtk.CssProvider ();
            style_context.add_provider (style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        string css = """
            .panel {
                transition: all %ums ease-in-out;
            }
        """.printf (animation_duration);

        try {
            style_provider.load_from_data (css, css.length);
        } catch (Error e) {
            warning ("Parsing own style configuration failed: %s", e.message);
        }

        switch (state) {
            case Services.BackgroundState.DARK :
                style_context.add_class ("color-light");
                style_context.remove_class ("color-dark");
                style_context.remove_class ("maximized");
                style_context.remove_class ("translucent");
                break;
            case Services.BackgroundState.LIGHT:
                style_context.add_class ("color-dark");
                style_context.remove_class ("color-light");
                style_context.remove_class ("maximized");
                style_context.remove_class ("translucent");
                break;
            case Services.BackgroundState.MAXIMIZED:
                style_context.add_class ("maximized");
                style_context.remove_class ("color-light");
                style_context.remove_class ("color-dark");
                style_context.remove_class ("translucent");
                break;
            case Services.BackgroundState.TRANSLUCENT_DARK:
                style_context.add_class ("translucent");
                style_context.add_class ("color-light");
                style_context.remove_class ("color-dark");
                style_context.remove_class ("maximized");
                break;
            case Services.BackgroundState.TRANSLUCENT_LIGHT:
                style_context.add_class ("translucent");
                style_context.add_class ("color-dark");
                style_context.remove_class ("color-light");
                style_context.remove_class ("maximized");
                break;
        }
    }
}
