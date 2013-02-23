using Gtk;

public class Main {

  class AppStatusIcon : Window {
    private StatusIcon trayicon;
    private Gtk.Menu menuSystem;

    public AppStatusIcon() {
      /* Create tray icon */
      trayicon = new StatusIcon.from_stock(Stock.HOME);
      trayicon.set_tooltip_text ("Tray");
      trayicon.set_visible(true);

      trayicon.activate.connect(about_clicked);

      create_menuSystem();
      trayicon.popup_menu.connect(menuSystem_popup);
    }

    /* Create menu for right button */
    public void create_menuSystem() {
      menuSystem = new Gtk.Menu();
      var menuAbout = new ImageMenuItem.from_stock(Stock.ABOUT, null);
      menuAbout.activate.connect(about_clicked);
      menuSystem.append(menuAbout);
      var menuQuit = new ImageMenuItem.from_stock(Stock.QUIT, null);
      menuQuit.activate.connect(Gtk.main_quit);
      menuSystem.append(menuQuit);
      menuSystem.show_all();
    }

    /* Show popup menu on right button */
    private void menuSystem_popup(uint button, uint time) {
      menuSystem.popup(null, null, null, button, time);
    }

    private void about_clicked() {
      var about = new AboutDialog();
      about.set_version("0.0.0");
      about.set_program_name("Tray");
      about.set_comments("Tray utility");
      about.set_copyright("vala");
      about.run();
      about.hide();
    }
  }

  public static int main (string[] args) {
    Gtk.init(ref args);
    var App = new AppStatusIcon();
    App.hide();
    Gtk.main();
    return 0;
  }
}