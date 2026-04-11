local CoreGui = game:GetService("CoreGui") :: CoreGui
local SelectionService = game:GetService("Selection") :: Selection

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

	local observableState = Controller.createState()
	local controller = Controller.new(observableState)

	local function App()
		local dockRef = React.useRef(dock)
		local modelStateRef = React.useRef({} :: { [Widget.ListElement]: Controller.ModelState })

		local observedState = observableState:use()
		local captureRect, setCaptureRect = React.useState(Rect.new(0, 0, 0, 0))
		local disabled, setDisabled = React.useState(false)
		local isEnabled = Hooks.useRefProperty(dockRef, "Enabled", false)

		React.useEffect(function()
			local onClick = button.Click:Connect(function()
				dock.Enabled = not dock.Enabled
			end)

			return function()
				onClick:Disconnect()
			end
		end, {})

		React.useEffect(function()
			if not isEnabled then
				controller:unfocus()

				for element, modelState in modelStateRef.current do
					modelState.instance:Destroy()
					modelStateRef.current[element] = nil
				end
			end
		end, { isEnabled })

		dock.Enabled = isEnabled
		button:SetActive(isEnabled)

		-- stylua: ignore
		return isEnabled and React.createElement(React.Fragment, nil, {
			Widget = React.createElement(Widget, {
				OnCapture = function()
					setDisabled(true)

					local success, err: string? = pcall(function()
						assert(Photobooth.isConnected(), "Photobooth not detected.")
						assert(Photobooth.isCompatible(), "Photobooth version is incompatible.")

						hideWorkspace(function()
							local focusedModelState = controller:getFocusedModelState()
							if focusedModelState then
								local result = controller:capture()
								if result then
									result.Name = focusedModelState.instance.Name
									result.Parent = game:GetService("StarterGui")

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
							local prevFocusedModelState = controller:getFocusedModelState()
							for _, modelState in modelStateRef.current do
								controller:focus(modelState)
								Photobooth.yieldUntilNextFrame()

								local result = controller:capture()
								if result then
									result.Name = modelState.instance.Name
									result.Parent = folder
								end
							end

							folder.Name = "AutoCaptures"
							folder.Parent = game:GetService("StarterGui")

							plugin:SelectRibbonTool(Enum.RibbonTool.Select, UDim2.fromOffset(0, 0))
							SelectionService:Set({ folder })

							if prevFocusedModelState then
								controller:focus(prevFocusedModelState)
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

					local modelState = element and modelStateRef.current[element]
					if modelState then
						controller:focus(modelState)
					end
				end,
				OnListElementAdded = function(element)
					if not modelStateRef.current[element] then
						local pvInstanceCopy = element.instance:Clone()
						local model = Instance.new("Model")
						pvInstanceCopy.Parent = model
						model.Name = pvInstanceCopy.Name
						model.WorldPivot = model:GetPivot() * pvInstanceCopy:GetPivot().Rotation:Inverse()
						model:PivotTo(CFrame.identity)
						modelStateRef.current[element] = {
							instance = model,
							cameraCF = CFrame.identity,
						}
					end
				end,
				OnListElementRemoved = function(element)
					if modelStateRef.current[element] then
						modelStateRef.current[element].instance:Destroy()
						modelStateRef.current[element] = nil
					end
				end,

				ObservableState = observableState,
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
						IsFullScreen = observedState.IsFullScreen,
						Resolution = observedState.CaptureSize,

						PaddingVisible = observedState.FitType ~= "Free" and observedState.PaddingVisible,
						PaddingTop = if observedState.PaddingUniform
							then observedState.Padding
							else observedState.PaddingTop,
						PaddingBottom = if observedState.PaddingUniform
							then observedState.Padding
							else observedState.PaddingBottom,
						PaddingLeft = if observedState.PaddingUniform
							then observedState.Padding
							else observedState.PaddingLeft,
						PaddingRight = if observedState.PaddingUniform
							then observedState.Padding
							else observedState.PaddingRight,

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
