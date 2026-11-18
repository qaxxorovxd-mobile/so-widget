(() => {
  "use strict";

  const root = document.documentElement;
  const motionPreference = window.matchMedia(
    "(prefers-reduced-motion: reduce)",
  );
  root.classList.add("js-ready");

  // Pause is global. Respect the OS preference even when controls are clicked.
  const motionButton = document.querySelector(".motion-toggle");
  const musicButton = document.querySelector(".play-toggle");
  const musicCard = document.querySelector(".hero-music");
  let userPaused = false;
  let musicPlaying = true;
  const isMotionPaused = () => userPaused || motionPreference.matches;

  function updateMusic() {
    const playing = musicPlaying && !isMotionPaused();
    musicCard.classList.toggle("music-paused", !playing);
    musicButton.setAttribute("aria-pressed", String(playing));
    musicButton.setAttribute(
      "aria-label",
      playing
        ? "Pause music preview animation"
        : "Play music preview animation",
    );
    musicButton.querySelector(".play-glyph").textContent = playing ? "Ⅱ" : "▶";
    musicButton.disabled = isMotionPaused();
  }

  function updateMotion() {
    const paused = isMotionPaused();
    root.classList.toggle("motion-paused", paused);
    motionButton.setAttribute("aria-pressed", String(paused));
    motionButton.textContent = motionPreference.matches
      ? "Reduced motion enabled"
      : paused
        ? "Resume motion ▷"
        : "Pause motion Ⅱ";
    motionButton.disabled = motionPreference.matches;
    updateMusic();
  }

  motionButton.addEventListener("click", () => {
    userPaused = !userPaused;
    updateMotion();
  });
  motionPreference.addEventListener("change", updateMotion);
  musicButton.addEventListener("click", () => {
    musicPlaying = !musicPlaying;
    updateMusic();
  });
  updateMotion();

  // Only hide content when the observer is available and successfully installed.
  if ("IntersectionObserver" in window && !isMotionPaused()) {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.08 },
    );
    document.querySelectorAll(".reveal").forEach((element) => {
      // Already visible content shouldn't disappear during script startup.
      if (element.getBoundingClientRect().top < window.innerHeight) return;
      element.classList.add("is-pending");
      observer.observe(element);
    });
  }

  // Mobile navigation remains a standard set of keyboard-accessible links.
  const menuButton = document.querySelector(".menu-toggle");
  const navigation = document.querySelector("#navigation");
  const mobileQuery = window.matchMedia("(max-width: 700px)");
  function closeMenu(returnFocus = false) {
    menuButton.setAttribute("aria-expanded", "false");
    menuButton.setAttribute("aria-label", "Open menu");
    navigation.classList.remove("is-open");
    if (returnFocus) menuButton.focus();
  }
  menuButton.addEventListener("click", () => {
    const open = menuButton.getAttribute("aria-expanded") !== "true";
    menuButton.setAttribute("aria-expanded", String(open));
    menuButton.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    navigation.classList.toggle("is-open", open);
  });
  navigation.addEventListener("click", (event) => {
    if (event.target.closest("a")) closeMenu();
  });
  document.addEventListener("keydown", (event) => {
    if (
      event.key === "Escape" &&
      menuButton.getAttribute("aria-expanded") === "true"
    )
      closeMenu(true);
  });
  document.addEventListener("click", (event) => {
    if (!event.target.closest(".site-header")) closeMenu();
  });
  document.addEventListener("focusin", (event) => {
    if (!event.target.closest(".site-header")) closeMenu();
  });
  mobileQuery.addEventListener("change", () => closeMenu());

  const collections = {
    essential: {
      number: "01—10",
      title: "Your day, at a glance.",
      description:
        "The time, the forecast, the moments that matter. A little clarity before you even open an app.",
      color: "#e5eadb",
      examples: [
        ["Chrono", "09:41", "Tuesday, November 17"],
        ["Atmosphere", "24°", "A little sunshine for your day."],
      ],
      names: [
        "Chrono",
        "Power",
        "Atmosphere",
        "Forecast",
        "Calendar",
        "Countdown",
        "World Clock",
        "Sun Cycle",
        "Moon Phase",
        "Air Quality",
      ],
    },
    media: {
      number: "6 WIDGETS",
      title: "Find your own rhythm.",
      description:
        "Six ways to wear your favorite song. Live artwork and playback controls, connected to the player you already love.",
      color: "#e9dfd4",
      examples: [
        ["Vinyl", "Side A", "Your daily soundtrack."],
        ["Wave", "▂▅▃▇▂", "A screen with a little rhythm."],
      ],
      names: ["Vinyl", "Cover", "Wave", "Disc", "Lyric Type", "Capsule"],
    },
    devices: {
      number: "4 WIDGETS",
      title: "A little more connected.",
      description:
        "Headphones, battery levels, storage and quick controls. Keep the essentials close without getting in your way.",
      color: "#dce5e8",
      examples: [
        ["Batteries", "86%", "Good to go."],
        ["Storage", "42 GB", "A little room for more."],
      ],
      names: ["Bluetooth", "Controls", "Batteries", "Storage"],
    },
    productivity: {
      number: "10 WIDGETS",
      title: "Space to do your thing.",
      description:
        "A focus session. A fresh idea. One small habit. Make room for the things you want to get done.",
      color: "#e6e3d4",
      examples: [
        ["Focus", "25:00", "One thing at a time."],
        ["Tasks", "3 / 5", "A little closer to done."],
      ],
      names: [
        "Focus",
        "Tasks",
        "Habit",
        "Notes",
        "Schedule",
        "Progress",
        "Time Tracker",
        "Clipboard",
        "Quick Links",
        "Daily Brief",
      ],
    },
    digital: {
      number: "10 WIDGETS",
      title: "Your world, in the loop.",
      description:
        "Stay close to your projects, your network and the numbers you follow. Useful signals, without the noise.",
      color: "#dfe0eb",
      examples: [
        ["GitHub Pulse", "24", "Contributions this week."],
        ["Server Status", "Online", "Everything is looking good."],
      ],
      names: [
        "System Pulse",
        "Network",
        "GitHub Pulse",
        "Server Status",
        "Crypto Market",
        "Currency",
        "Stock Watch",
        "Package Tracker",
        "Website Monitor",
        "Dev Feed",
      ],
    },
    lifestyle: {
      number: "10 WIDGETS",
      title: "A little time for you.",
      description:
        "Water, movement, music and memories. Small reminders that help your home screen fit your everyday rhythm.",
      color: "#e9ddd8",
      examples: [
        ["Hydration", "1.5 L", "A small sip. A good habit."],
        ["Reading Tracker", "32 / 50", "Just one more chapter."],
      ],
      names: [
        "Now Playing",
        "Soundscape",
        "Photo Frame",
        "Daily Quote",
        "Mood Journal",
        "Hydration",
        "Sleep Rhythm",
        "Fitness Rings",
        "Reading Tracker",
        "Prayer Times",
      ],
    },
    creative: {
      number: "10 WIDGETS",
      title: "Keep a little curiosity.",
      description:
        "A new word, a fresh color, a window into space. Little discoveries that make the everyday more interesting.",
      color: "#e5dfeb",
      examples: [
        ["Color Studio", "#BFD5A8", "Your next favorite color."],
        ["Word of the Day", "Serene", "Calm, peaceful, untroubled."],
      ],
      names: [
        "Minimal News",
        "Space Live",
        "Earth Events",
        "Color Studio",
        "Daily Wallpaper",
        "Word of the Day",
        "Language Cards",
        "QR Studio",
        "Mini Calculator",
        "Quick Translate",
      ],
    },
  };
  const collectionButtons = [...document.querySelectorAll("[data-collection]")];
  const collectionStage = document.querySelector("#collection-stage");
  let collectionAnimation;
  collectionButtons.forEach((button) =>
    button.addEventListener("click", () => {
      const collection = collections[button.dataset.collection];
      if (!collection || button.getAttribute("aria-pressed") === "true") return;
      collectionButtons.forEach((item) =>
        item.setAttribute("aria-pressed", String(item === button)),
      );
      document.querySelector("#collection-number").textContent =
        collection.number;
      document.querySelector("#collection-title").textContent =
        collection.title;
      document.querySelector("#collection-description").textContent =
        collection.description;
      collectionStage.style.setProperty("--collection-bg", collection.color);
      const examples = collection.examples.map(([name, value, description]) => {
        const card = document.createElement("div");
        card.className = "sample-widget";
        for (const [tag, text] of [
          ["span", name],
          ["strong", value],
          ["small", description],
        ]) {
          const child = document.createElement(tag);
          child.textContent = text;
          if (tag === "strong" && value.length > 6)
            child.style.fontSize = "clamp(22px, 2.8vw, 40px)";
          card.append(child);
        }
        return card;
      });
      document
        .querySelector("#collection-examples")
        .replaceChildren(...examples);
      document.querySelector("#collection-list").replaceChildren(
        ...collection.names.map((name) => {
          const item = document.createElement("span");
          item.textContent = name;
          return item;
        }),
      );
      if (!isMotionPaused() && typeof collectionStage.animate === "function") {
        collectionAnimation?.cancel();
        collectionAnimation = collectionStage.animate(
          [
            { opacity: 0.55, transform: "translateY(7px)" },
            { opacity: 1, transform: "translateY(0)" },
          ],
          { duration: 380, easing: "cubic-bezier(.22,1,.36,1)" },
        );
      }
    }),
  );

  const themeNames = {
    mint: "Mint",
    rose: "Rosé",
    sand: "Sand",
    ocean: "Ocean",
    amethyst: "Amethyst",
  };
  const themeButtons = [...document.querySelectorAll("[data-theme]")];
  themeButtons.forEach((button) =>
    button.addEventListener("click", () => {
      const theme = button.dataset.theme;
      document.querySelector(".studio-demo").dataset.palette = theme;
      document.querySelector("#theme-name").textContent = themeNames[theme];
      themeButtons.forEach((item) =>
        item.setAttribute("aria-pressed", String(item === button)),
      );
    }),
  );

  const gallery = document.querySelector("#screenshots");
  const previousButton = document.querySelector("#gallery-prev");
  const nextButton = document.querySelector("#gallery-next");
  function updateGalleryControls() {
    previousButton.disabled = gallery.scrollLeft <= 2;
    nextButton.disabled =
      gallery.scrollLeft + gallery.clientWidth >= gallery.scrollWidth - 2;
  }
  function moveGallery(direction) {
    const distance =
      gallery.querySelector("figure").getBoundingClientRect().width +
      parseFloat(getComputedStyle(gallery).columnGap);
    gallery.scrollBy({
      left: direction * distance,
      behavior: isMotionPaused() ? "instant" : "smooth",
    });
  }
  previousButton.addEventListener("click", () => moveGallery(-1));
  nextButton.addEventListener("click", () => moveGallery(1));
  gallery.addEventListener("keydown", (event) => {
    if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
      event.preventDefault();
      moveGallery(event.key === "ArrowRight" ? 1 : -1);
    }
  });
  gallery.addEventListener("scroll", updateGalleryControls, { passive: true });
  window.addEventListener("resize", updateGalleryControls, { passive: true });
  updateGalleryControls();

  // Stop decorative work in background tabs without losing the user's choice.
  document.addEventListener("visibilitychange", () => {
    root.classList.toggle("motion-paused", document.hidden || isMotionPaused());
  });
})();
