local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local SelectionService = game:GetService("Selection")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Photobooth = require(pluginRoot.Packages.PhotoboothBindings)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local ButtonIcon = require(uiRoot.ButtonIcon)
local Hooks = require(uiRoot.Hooks)

local FitterWindow = require(script.Components.FitterWindow)
local Widget = require(script.Components.Widget)

local Controller = require(script.Controller)

local AutoCapture = {}

local function hideWorkspace(callback: () -> ())
	local terrain = workspace.Terrain
	local camera = workspace.CurrentCamera
	local children = workspace:GetChildren()

	local hidden = {}
	for _, child in children do
		if child ~= camera and child ~= terrain then
			child.Parent = nil
			table.insert(hidden, child)
		end
	end

	callback()

	for _, child in hidden do
		child.Parent = workspace
	end
end

local function useController()
	local controller = Hooks.useConstant(function()
		return Controller.new()
	end)

	React.useEffect(function()
		return function()
			controller:Destroy()
		end
	end, {})

	return controller
end

local function appComponent(props: {})
	local modelsRef = React.useRef({} :: { [Widget.ListElement]: Model })

	local controller = useController()
	local static = controller.staticObservableState:use()
	local dynamic = controller.dynamicObservableState:use()

	local captureRect, setCaptureRect = React.useState(Rect.new(0, 0, 0, 0))
	local disabled, setDisabled = React.useState(false)

	React.useEffect(function()
		return function()
			controller:unfocus()

			for element, _model in modelsRef.current do
				controller:unloadModel(modelsRef.current[element])
				modelsRef.current[element]:Destroy()
				modelsRef.current[element] = nil
			end
		end
	end, {})

	return React.createElement(React.Fragment, nil, {
		Widget = React.createElement(Widget, {
			OnCapture = function()
				setDisabled(true)

				local success, err: string? = pcall(function()
					assert(Photobooth.isConnected(), "Photobooth not detected.")
					assert(Photobooth.isCompatible(), "Photobooth version is incompatible.")

					hideWorkspace(function()
						local focusedModel = controller:getFocusedModel()
						if focusedModel then
							local result = controller:capture()
							if result then
								local captureName = (focusedModel:GetAttribute("CaptureName") :: string?) or "Capture"
								result.Name = captureName
								result.Parent = StarterGui

								plugin:SelectRibbonTool(Enum.RibbonTool.Select, UDim2.fromOffset(0, 0))
								SelectionService:Set({ result })
							end
						end
					end)
				end)

				if not success then
					warn(err)
				end

				setDisabled(false)
			end,
			OnCaptureAll = function()
				setDisabled(true)

				local success, err: string? = pcall(function()
					assert(Photobooth.isConnected(), "Photobooth not detected.")
					assert(Photobooth.isCompatible(), "Photobooth version is incompatible.")

					hideWorkspace(function()
						local folder = Instance.new("Folder")
						local prevFocusedModel = controller:getFocusedModel()

						for i, model in controller:getModels() do
							controller:focus(true, model)
							Photobooth.yieldUntilNextFrame()

							local result = controller:capture()
							if result then
								local captureName = (model:GetAttribute("CaptureName") :: string?) or "Capture"
								result.Name = `{i}_{captureName}`
								result.Parent = folder
							end
						end

						folder.Name = "AutoCaptures"
						folder.Parent = StarterGui

						plugin:SelectRibbonTool(Enum.RibbonTool.Select, UDim2.fromOffset(0, 0))
						SelectionService:Set({ folder })

						if prevFocusedModel then
							controller:focus(false, prevFocusedModel)
						else
							controller:unfocus()
						end
					end)
				end)

				if not success then
					warn(err)
				end

				setDisabled(false)
			end,

			OnListElementSelected = function(element)
				controller:unfocus()

				local model = element and modelsRef.current[element]
				if model then
					controller:focus(false, model)
				end
			end,
			OnListElementAdded = function(element)
				if not modelsRef.current[element] then
					local archivable = element.instance.Archivable
					element.instance.Archivable = true
					local pvInstanceCopy = element.instance:Clone()
					element.instance.Archivable = archivable
					pvInstanceCopy.Archivable = archivable
					local model = Instance.new("Model")
					model.Archivable = false
					pvInstanceCopy.Parent = model

					local aabbCenterCF, _aabbSize = model:GetBoundingBox()
					model.Name = "AutoCaptureModel"
					model.WorldPivot = aabbCenterCF * pvInstanceCopy:GetPivot().Rotation:Inverse()
					model:PivotTo(CFrame.identity)
					model:SetAttribute("CaptureName", pvInstanceCopy.Name)

					modelsRef.current[element] = model
					controller:loadModel(modelsRef.current[element])
				end
			end,
			OnListElementRemoved = function(element)
				if modelsRef.current[element] then
					controller:unloadModel(modelsRef.current[element])
					modelsRef.current[element]:Destroy()
					modelsRef.current[element] = nil
				end
			end,

			Controller = controller,
			CaptureRect = captureRect,
			Disabled = disabled,
		}),

		FitterWindow = ReactRoblox.createPortal(
			React.createElement("ScreenGui", {
				Name = "FitterWindow",
				Archivable = false,
				IgnoreGuiInset = true,
				ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			}, {
				Core = React.createElement(FitterWindow, {
					IsFullScreen = dynamic.isFullScreen,
					Resolution = dynamic.captureSize,
					AnimationTrack = static.animationTrack,

					PaddingVisible = dynamic.fitType ~= "Free" and dynamic.paddingVisible,
					PaddingTop = if dynamic.paddingUniform then dynamic.padding else dynamic.paddingTop,
					PaddingBottom = if dynamic.paddingUniform then dynamic.padding else dynamic.paddingBottom,
					PaddingLeft = if dynamic.paddingUniform then dynamic.padding else dynamic.paddingLeft,
					PaddingRight = if dynamic.paddingUniform then dynamic.padding else dynamic.paddingRight,

					OnCaptureRectChanged = function(newRect)
						controller:setCaptureRect(newRect)
						setCaptureRect(newRect)
					end,

					OnPaddedRectChanged = function(newRect)
						controller:setPaddedRect(newRect)
					end,

					Disabled = disabled,
				}),
			}),
			CoreGui
		),
	})
end

function AutoCapture.mount(plugin: Plugin, toolbar: PluginToolbar)
	-- stylua: ignore
	local button = toolbar:CreateButton(
		"egomoose_photobooth_addon_auto_capture",
		"Photobooth Auto Capture", "", "Auto"
	)

	ButtonIcon.listen(button, "switch-camera")

	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 300, 600, 300, 600)
	local dock = plugin:CreateDockWidgetPluginGuiAsync("egomoose_photobooth_addon_auto_capture", info)
	dock.Name = "Photobooth Auto Capture"
	dock.Title = "Photobooth - Auto Capture"
	dock.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local function App()
		local dockRef = React.useRef(dock)
		local isEnabled = Hooks.useRefProperty(dockRef, "Enabled", false)

		React.useEffect(function()
			local onClick = button.Click:Connect(function()
				dock.Enabled = not dock.Enabled
			end)

			return function()
				onClick:Disconnect()
			end
		end, {})

		dock.Enabled = isEnabled
		button:SetActive(isEnabled)

		return isEnabled and React.createElement(appComponent, {})
	end

	local dockRoot = ReactRoblox.createRoot(dock)
	dockRoot:render(React.createElement(StudioComponents.PluginProvider, {
		Plugin = plugin,
	}, {
		App = React.createElement(App),
	}))

	plugin.Unloading:Connect(function()
		dockRoot:unmount()
		dock:Destroy()
		button:Destroy()
	end)
end

return AutoCapture
