# photobooth-plugin-addons

Photobooth plugin addons is a suite of additional tools that make use of Photobooth's bindings feature to add new interfaces and features that extend upon what the base plugin can do. These addons will not work correctly unless the user has the base photobooth plugin installed.

At the time of writing there is a roblox bug with parallel luau that causes studio to crash under certain circumstances. Until Roblox fixes that bug I do not intend to release these addons on the creator store. The post-processing addon in particular relies heavily on parallel luau to run efficiently. You can try using a pre-release (which will work), but you risk crashing studio in the event that bug happens.

## Auto-capture

The auto-capture tool is designed to ease the process of capturing many targets quickly. Simply open the widget and add your selected targets to the queue. Added targets will be placed at the world identity so it may be worth clearing that location. On capture all other elements in the workspace will be temporarily hidden.

Once added you can jump between targets and change the configuration as desired. A number of the properties are self-explanatory, but there are a few worth highlighting:

### Synchronized

This property determines if all the targets in the queue should use the same configuration and camera angle as each other. In many cases you will likely want the exact same angle, resolution, etc for each capture target, but situations where you don't this is the property for you.

Toggle it off, change any properties, and then switch targets. The configurations for each item will behave independently.

### Fit Type

This property determines how the camera should behave when focusing on a capture target.

- **Orbital** - Calculates the minimum fixed distance required such that any possible camera angle will contain the target. This does not account for animation transforms.
- **Point Cloud** - Uses the point cloud of the target and the camera angle to determine the exact fit cframe. This does account for animation transforms.
- **Free** - Let's you freely move the camera around the workspace to achieve any camera angle.

### Animation

Any capture targets with animators can have an animation applied by pasting an animation id to the animation instance in the camera. This will bring up a playback bar that can be used to set the exact frame as desired.

https://github.com/user-attachments/assets/6ea3aeb8-7cf8-453d-b913-ebcb7741fdf1

## Post-processing

The post-processing tool is designed to help add common effects to captures without the need for external tools like photoshop, etc. Open the widget and select captures in the explorer. From there you can define how you want to process the image by using layers and effects.

Some built-in presets are provided to get you started, but you can always save your own!

https://github.com/user-attachments/assets/867f403b-c3f1-4231-a203-8239497b56b1

