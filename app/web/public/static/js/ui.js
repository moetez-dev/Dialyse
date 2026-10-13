/* Comportements d'interface partagés : volet latéral et thème clair/sombre. */

/* ---------------------------------------------------------------- sidebar */
(() => {
  const sidebar = document.getElementById("sidebar");
  const overlay = document.getElementById("sidebarOverlay");
  const btn = document.querySelector("[data-sidebar-toggle]");

  if (!sidebar || !overlay || !btn) return;

  const open = () => {
    sidebar.classList.remove("-translate-x-full");
    sidebar.classList.add("translate-x-0");
    overlay.classList.remove("hidden");
  };

  const close = () => {
    sidebar.classList.add("-translate-x-full");
    sidebar.classList.remove("translate-x-0");
    overlay.classList.add("hidden");
  };

  btn.addEventListener("click", () => {
    const isClosed = sidebar.classList.contains("-translate-x-full");
    isClosed ? open() : close();
  });

  overlay.addEventListener("click", close);

  // Le volet se referme à l'Échap quand il est ouvert en superposition.
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !overlay.classList.contains("hidden")) close();
  });
})();

/* ------------------------------------------------------------------ thème */
(() => {
  const root = document.documentElement;

  const current = () => (root.classList.contains("dark") ? "dark" : "light");

  const apply = (theme) => {
    root.classList.toggle("dark", theme === "dark");
    try {
      localStorage.setItem("theme", theme);
    } catch (e) {
      /* navigation privée : le thème ne survivra pas au rechargement */
    }
    // Les graphiques relisent leurs couleurs dans les tokens CSS.
    document.dispatchEvent(
      new CustomEvent("dialyse:themechange", { detail: { theme } })
    );
  };

  document.querySelectorAll("[data-theme-toggle]").forEach((btn) => {
    btn.addEventListener("click", () => {
      apply(current() === "dark" ? "light" : "dark");
    });
  });
})();
