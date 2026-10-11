# Dark × Lime

`dark-lime-mockup.png` is the approved visual reference for the home and live workout screens.
The implementation uses SwiftUI, real workout totals, scrollable content, and pinned primary actions.
The free/program selection, intensity, goals, gait mode, units, pause/resume, finish, and history features remain available.

## App icon

The production icon is `../Sources/TreadmillTracker/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
It is an opaque 1024 × 1024 PNG. `project.yml` selects the `AppIcon` asset.
Generated with the built-in image generation tool, then resized for the asset catalog.
No developer API key or runtime image generation is required.

Generation prompt:

> Use case: logo-brand. Create ONE finished iOS app icon image, square 1024x1024 full bleed opaque raster artwork. It is for a treadmill running and indoor walking tracker app named Treadmill Tracker. No text or letters, no wordmark, no surrounding presentation canvas, no phone mockup, no rounded outer corners; the operating system will mask the square. Solid near-black background #0B0D0C fills all the way to every edge. Center a bold, extremely clean electric-lime #C8FF48 pictogram that unmistakably depicts a person RUNNING ON A TREADMILL. Side-profile icon: a clear dynamic human runner torso, bent arms, circular head, one bent lifted leg, one foot toward the moving treadmill belt. The machine must clearly read as a treadmill: a wide short slightly inclined belt/deck underneath feet, a short upturned front support and single forward console upright with small console top. Use one coherent bold geometric silhouette with negative-space separation of limbs, crisp smooth antialiased edges, no thin tiny parts. Make the running person dominant and the treadmill deck a clean recognizable foundation, visually balanced and centered, use roughly 72 percent of square width and 72 percent of square height, ample margin. Treadmill upright on right side, runner facing right. Premium sport equipment visual character, minimal and strong, simple vector-like flat illustration in two colors. Avoid gyms, backgrounds, photorealism, 3D, shadows, neon glows, gradients, extra circles, borders, icon grids, multiple variants, watermarks, brand logos. Must remain recognizable at 40px.
