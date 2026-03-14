# **Aegletes** (working name, considering other app names)

This is an iOS app designed for photography. it is primarily a **light meter and exposure calculator** for any kind of photography with an added **film roll database** to store and track the lifecycle of all film rolls for the user. 

The app leverages the device camera and GPU to provide a responsive, accurate light meter and exposure calculator.

---

## Overview

Aegletes is designed for film photographers who want the convenience and flexibility of a digital light meter on their phone. At a high level, the app:

- Uses the onboard **iPhone camera** as a metering sensor.  
- Computes exposure based on **user-selected settings** (e.g., ISO, aperture, shutter).  
- Displays a **live histogram** of the scene to show tonal distribution.  
- Stores persistent information about **film rolls and exposures** for later reference.

The core of the app is split between:

- **Metering & visualization** (real-time camera feed, histogram, exposure calculations).  
- **Film roll data & settings** (storing film stocks, speeds, and related metadata).

---

## Core Features

**Light Meter Mode** vs **Manual Mode**
- **In Light Meter Mode**
  - **Real-time light metering**
    - Uses the iPhone camera as a light sensor.
    - Uses the iPhone's automatic exposure adjustments to calculate an Exposure Value (EV) error 
    - Shows a live preview and computes optimal exposure settings for the given scene using the EV error.
    - Prioritizes **overexposing** the scene as opposed to **underexposing** while still minimizing EV error.
    - Provides a 'Low Light Warning' for scenes that cannot be reasonably well represented with the given exposure settings.

  - **Live histogram**
    - GPU-accelerated histogram using Metal to analyze incoming frames.
    - Visual feedback on how highlights, midtones, and shadows are distributed.
    - Helps judge whether a chosen exposure risks clipping or underexposure.
    - A small, unobtrusive display element that is toggleable by tapping the "EV Δ" badge. 

  - **Exposure configuration**
    - User-selectable exposure parameters (e.g., ISO/film speed, aperture, shutter) with toggleable locks.
    - In Light Meter mode, the automartic exposure calculation respects a lock as an unchangeable value and adjusts the other parameters to compensate.

  - **Highlight/Shadow exposure compensation**
    - Features pinch-to-zoom that automatically updates exposure settings based on what is present in the preview frame


- **In Manual Mode**
  - **Live exposure preview**
     - Uses the current exposure settings and compares to the iPhone's automatic exposure settings to calculate EV error.
     - Then applies a global lightening/darkening filter to the preview image to simulate the scene with the given settings.
     - Removes all locks from the UI and never changes an exposure variable without user input. 
---

**Film Roll Database & Lifecycle Tracker**
  - The Film Database is accessed by tapping the folder icon in the top right of the camera view and turns into a film library and roll lifecycle tracker:
  - The main screen is a list of `Film Rolls` that captures manufacturer, stock, format (35mm/120/large format), type (color/B&W/slide), box ISO, effective ISO, camera, freeform notes, and lifecycle status
    - Each film roll entry has a lifecycle status that logically progresses from `In Storage` -> `Loaded` -> `Finished` -> `Developed` -> `Scanning` -> `Archived`
    - Each entry also captures timestamps for when the roll was created, loaded, finished, and scanned.
  - Tapping an individual `Film Roll` entry will open a detailed view of the roll with all metadata presented along with the option to edit any attribute.
  - Roll lifecycle is managed by updating the status of each individual roll through simple swipe gestures or through the detail view. 
  - The Film DB also groups rolls by shared film identity (same manufacturer/stock/type/format/box ISO).
  - The main root view features a selection bar that allows for filtering by lifecycle (`All`, `In Storage`, `Loaded`, `Processing`, `Archived`).
    - All rolls with the status `Archived` are only viewable in the `Archived` tab to avoid cluttering the other tabs.
  - A JSON‑backed `FilmRollDatabase` persistently stores all rolls on disk and maintains catalogs of common manufacturers, stocks, film formats, film types, and ISO values that power the pickers in the roll editor screens.

  - The database also maintains a user‑editable list of camera names so rolls can be tagged to specific bodies, and you can manage that list separately via the **Manage Cameras** screen.

---

## App Status

Aegletes is still in a 'Beta' phase. Bugs need to be discovered and UX needs to be refined. The current focus is on:

- Refining exposure calculations based on camera input.   
- Expanding the film roll database to include more manufacturers and film stocks. Simplify the process of adding film rolls to the users personal store.
- Potentially linking the light meter exposure settings to a specific frame on a 'loaded' roll in the users database.
- Adding an export .json feature so the user can conveniently view their data outside of the app.
