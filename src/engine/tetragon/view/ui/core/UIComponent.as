/* * hexagonlib - Multi-Purpose ActionScript 3 Library. *       __    __ *    __/  \__/  \__    __ *   /  \__/HEXAGON \__/  \ *   \__/  \__/  LIBRARY _/ *            \__/  \__/ * * Licensed under the MIT License *  * Copyright (c) 2007-2008 Sascha Balkau / Hexagon Star Softworks *  * Permission is hereby granted, free of charge, to any person obtaining a copy of * this software and associated documentation files (the "Software"), to deal in * the Software without restriction, including without limitation the rights to * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of * the Software, and to permit persons to whom the Software is furnished to do so, * subject to the following conditions: *  * The above copyright notice and this permission notice shall be included in all * copies or substantial portions of the Software. *  * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */package tetragon.view.ui.core{	import tetragon.view.ui.constants.InvalidationType;	import tetragon.view.ui.constants.UIStyles;	import tetragon.view.ui.event.UIComponentEvent;	import tetragon.view.ui.managers.FocusManager;	import tetragon.view.ui.managers.IFocusManager;	import tetragon.view.ui.managers.IFocusManagerComponent;	import tetragon.view.ui.managers.StyleManager;	import com.hexagonstar.util.debug.HLog;	import flash.display.DisplayObject;	import flash.display.InteractiveObject;	import flash.display.Sprite;	import flash.events.Event;	import flash.events.EventDispatcher;	import flash.events.FocusEvent;	import flash.events.KeyboardEvent;	import flash.text.TextFormat;	import flash.utils.Dictionary;	import flash.utils.getDefinitionByName;			[Event(name="move", type="tetragon.view.ui.event.UIComponentEvent")]	[Event(name="resize", type="tetragon.view.ui.event.UIComponentEvent")]	[Event(name="show", type="tetragon.view.ui.event.UIComponentEvent")]	[Event(name="hide", type="tetragon.view.ui.event.UIComponentEvent")]		[Style(name="focusRectSkin", type="Class")]	[Style(name="focusRectPadding", type="Number", format="Length")]	[Style(name="textFormat", type="flash.text.TextFormat")]	[Style(name="disabledTextFormat", type="flash.text.TextFormat")]			/**	 * The UIComponent class is the base class for all visual components, both	 * interactive and non-interactive. Interactive components are defined as components	 * that receive user input such as keyboard or mouse activity. Noninteractive	 * components are used to display data; they do not respond to user interaction. The	 * ProgressBar and UILoader components are examples of noninteractive components.	 * <p>	 * The Tab and arrow keys can be used to move focus to and over an interactive	 * component; an interactive component can accept low-level events such as input	 * from mouse and keyboard devices. An interactive component can also be disabled so	 * that it cannot receive mouse and keyboard input.</p>	 */	public class UIComponent extends Sprite	{		//-----------------------------------------------------------------------------------------
		// Properties
		//-----------------------------------------------------------------------------------------				/**		 * Indicates whether the current execution stack is within a call later phase.		 * @private		 */		public static var isCallLaterPhase:Boolean;				/**		 * Used when components are nested, and we want the parent component to handle draw		 * focus, not the child.		 * @private		 */		public var focusTarget:IFocusManagerComponent;				/** @private */		protected var _instanceStyles:Object;		/** @private */		protected var _sharedStyles:Object;		/** @private */		protected var _callLaterMethods:Dictionary;		/** @private */		protected var _invalidHash:Object;		/** @private */		protected var _focusRect:DisplayObject;		/** @private */		protected var _startWidth:Number;		/** @private */		protected var _startHeight:Number;		/** @private */		protected var _width:Number;		/** @private */		protected var _height:Number;		/** @private */		protected var _x:Number;		/** @private */		protected var _y:Number;		/** @private */		protected var _isEnabled:Boolean = true;		/** @private */		protected var _isUsingSkin:Boolean = true;		/** @private */		protected var _isFocused:Boolean;		/** @private */		protected var _isInvalidated:Boolean;		/** @private */		protected var _isErrorCaught:Boolean;				/** @private */		protected var _debug:Boolean;				/** @private */		private var _focusEnabled:Boolean = true;		/** @private */		private var _mouseFocusEnabled:Boolean = true;				/** @private */		private static var _focusManagers:Dictionary = new Dictionary(false);				/** @private */		private static var _defaultStyles:Object =		{			focusRectSkin:					"FocusRect",			focusRectPadding:				2,			textFormat:						ThemeAssets.guiText,			TextFormatDisabled:				ThemeAssets.guiTextDisabled,			defaultTextFormat:				ThemeAssets.guiText,			defaultTextFormatDisabled:		ThemeAssets.guiTextDisabled		};						//-----------------------------------------------------------------------------------------
		// Constructor
		//-----------------------------------------------------------------------------------------				/**		 * Creates a new UIComponent instance.		 */		public function UIComponent()		{			super();						_instanceStyles = {};			_sharedStyles = {};			_invalidHash = {};			_callLaterMethods = new Dictionary();						StyleManager.registerInstance(this);			configUI();			invalidate(InvalidationType.ALL);						/* We are tab enabled by default if IFocusManagerComponent */			tabEnabled = (this is IFocusManagerComponent);						/* We do our own focus drawing. */			focusRect = false;			/* Register for focus and keyboard events. */			if (tabEnabled)			{				addEventListener(FocusEvent.FOCUS_IN, onFocusIn);				addEventListener(FocusEvent.FOCUS_OUT, onFocusOut);				addEventListener(KeyboardEvent.KEY_DOWN, onKeyFocusDown);				addEventListener(KeyboardEvent.KEY_UP, onKeyFocusUp);			}						initFocusManager();		}						//-----------------------------------------------------------------------------------------
		// Public Methods
		//-----------------------------------------------------------------------------------------				/**		 * Merges the styles from multiple classes into one object. If a style is defined in		 * multiple objects, the first occurrence that is found is used.		 * 		 * @param list A comma-delimited list of objects that contain the default styles to		 *            be merged.		 * @return A default style object that contains the merged styles.		 */		public static function mergeStyles(...list:Array):Object		{			var styles:Object = {};			var l:int = list.length;						for (var i:int = 0; i < l; i++)			{				var styleList:Object = list[i];								for (var n:String in styleList)				{					if (styles[n]) continue;					styles[n] = list[i][n];				}			}			return styles;		}						/**		 * Validates and updates the properties and layout of this object, redrawing it if		 * necessary.		 * <p>		 * Properties that require substantial computation are normally not processed until		 * the script finishes executing. This is because setting one property could require		 * the processing of other properties. For example, setting the <code>width</code>		 * property may require that the widths of the children or parent of the object also		 * be recalculated. And if the script recalculates the width of the object more than		 * once, these interdependent properties may also require recalculating. Use this		 * method to manually override this behavior.</p>		 */		public function validateNow():void		{			invalidate(InvalidationType.ALL, false);			draw();		}						/**		 * Initiates an immediate draw operation, without invalidating everything as		 * <code>invalidateNow</code> does.		 */		public function drawNow():void		{			draw();		}						/**		 * Marks a property as invalid and redraws the component on the next frame unless		 * otherwise specified.		 * 		 * @param property The property to be invalidated.		 * @param isCallLater A Boolean value that indicates whether the component should be		 *            redrawn on the next frame. The default value is <code>true</code>.		 */		public function invalidate(property:String = InvalidationType.ALL,			isCallLater:Boolean = true):void		{			_invalidHash[property] = true;			if (isCallLater)			{				callLater(draw);			}		}						/**		 * Shows or hides the focus indicator on this component.		 * <p>		 * The UIComponent class implements this method by creating and positioning an		 * instance of the class that is specified by the <code>focusSkin</code> style.</p>		 * 		 * @param focused Indicates whether to show or hide the focus indicator. If this		 *            value is <code>true</code>, the focus indicator is shown; if this		 *            value is <code>false</code>, the focus indicator is hidden.		 */		public function drawFocus(focused:Boolean):void		{			/* We need to set isFocused here since there are drawFocus() calls from FM. */			_isFocused = focused;						/* Remove uiFocusRect if focus is turned off */			if (_focusRect && contains(_focusRect))			{				removeChild(_focusRect);				_focusRect = null;			}						/* Add focusRect to stage, and resize. If component is focused. */			if (_isFocused)			{				_focusRect = getDisplayObjectInstance(getStyleValue(UIStyles.FOCUSRECT_SKIN));				if (_focusRect)				{					var focusPadding:Number = getStyleValue(UIStyles.FOCUSRECT_PADDING);					_focusRect.x = -focusPadding;					_focusRect.y = -focusPadding;					_focusRect.width = width + (focusPadding * 2);					_focusRect.height = height + (focusPadding * 2);					addChildAt(_focusRect, 0);				}			}		}						/**		 * Sets the focus to this component. The component may in turn give the focus to a		 * subcomponent.		 * <p>		 * <strong>Note:</strong> Only the TextInput and TextArea components show a focus		 * indicator when this method sets the focus. All components show a focus indicator		 * when the user tabs to the component.</p>		 */		public function setFocus():void		{			if (stage) stage.focus = this;		}						/**		 * Retrieves the object that currently has focus.		 * <p>		 * Note that this method does not necessarily return the component that has focus.		 * It may return the internal subcomponent of the component that has focus. To get		 * the component that has focus, use the <code>focusManager.focus</code> property.</p>		 * 		 * @return The object that has focus; otherwise, this method returns		 *         <code>null</code>.		 */		public function getFocus():InteractiveObject		{			if (stage) return stage.focus;			return null;		}						/**		 * Deletes a style property from this component instance.		 * <p>		 * This does not necessarily cause the <code>getStyle()</code> method to return a		 * value of <code>undefined</code>.</p>		 * 		 * @param style The name of the style property.		 * @see #getStyle()		 * @see #setStyle()		 */		public function clearStyle(style:String):void		{			setStyle(style, null);		}						/**		 * Retrieves a style property that is set in the style lookup chain of the		 * component.		 * <p>		 * The type that this method returns varies depending on the style property that the		 * method retrieves. The range of possible types includes Boolean; String; Number;		 * int; a uint for an RGB color; a Class for a skin; or any kind of object.		 * </p>		 * <p>		 * If you call this method to retrieve a particular style property, it will be of a		 * known type that you can store in a variable of the same type. Type casting is not		 * necessary. Instead, a simple assignment statement like the following will work:		 * </p>		 * <listing>var backgroundColor:uint = getStyle("backgroundColor");</listing>		 * <p>		 * If the style property is not set in the style lookup chain, this method returns a		 * value of <code>undefined</code>. Note that <code>undefined</code> is a special		 * value that is not the same as <code>false</code>, "", <code>NaN</code>, 0, or		 * <code>null</code>. No valid style value is ever <code>undefined</code>. You can		 * use the static method <code>StyleManager.isValidStyleValue()</code> to test		 * whether a value was set.</p>		 * 		 * @param style The name of the style property.		 * @return Style value.		 * @see #clearStyle()		 * @see #setStyle()		 */		public function getStyle(style:String):Object		{			return _instanceStyles[style];		}						/**		 * Sets a style property on this component instance. This style may override a style		 * that was set globally.		 * <p>		 * Calling this method can result in decreased performance. Use it only when		 * necessary.</p>		 * 		 * @param style The name of the style property.		 * @param value The value of the style.		 * @see #getStyle()		 * @see #clearStyle()		 */		public function setStyle(style:String, value:Object):void		{			/* Use strict equality so we can set a style to null ... so if the			 * instanceStyles[style] == undefined, null is still set. We also			 * need to work around the specific use case of TextFormats. */			if (_instanceStyles[style] === value && !(value is TextFormat))			{				return;			}						_instanceStyles[style] = value;			invalidate(InvalidationType.STYLES);		}						/**		 * Sets the inherited style value to the specified style name and invalidates the		 * styles of the component.		 * 		 * @param name Style name.		 * @param style Style value.		 */		public function setSharedStyle(name:String, style:Object):void		{			if (_sharedStyles[name] === style && !(style is TextFormat))			{				return;			}						_sharedStyles[name] = style;						if (!_instanceStyles[name])			{				invalidate(InvalidationType.STYLES);			}		}						/**		 * Sets the component to the specified width and height.		 * 		 * @param width The width of the component, in pixels.		 * @param height The height of the component, in pixels.		 */		public function setSize(width:Number, height:Number):void		{			_width = width;			_height = height;			invalidate(InvalidationType.SIZE);			dispatchEvent(new UIComponentEvent(UIComponentEvent.RESIZE, false));		}						/**		 * Moves the component to the specified position within its parent. This has the		 * same effect as changing the component location by setting its <code>x</code> and		 * <code>y</code> properties. Calling this method triggers the		 * <code>ComponentEvent.MOVE</code> event to be dispatched.		 * <p>		 * To override the <code>updateDisplayList()</code> method in a custom component,		 * use the <code>move()</code> method instead of setting the <code>x</code> and		 * <code>y</code> properties. This is because a call to the <code>move()</code>		 * method causes a <code>move</code> event object to be dispatched immediately after		 * the move operation is complete. In contrast, when you change the component		 * location by setting the <code>x</code> and <code>y</code> properties, the event		 * object is dispatched on the next screen refresh.</p>		 * 		 * @param x The x coordinate value that specifies the position of the component		 *            within its parent, in pixels. This value is calculated from the left.		 * @param y The y coordinate value that specifies the position of the component		 *            within its parent, in pixels. This value is calculated from the top.		 * @see #x		 * @see #y		 */		public function move(x:Number, y:Number):void		{			_x = x;			_y = y;			super.x = Math.round(x);			super.y = Math.round(y);			dispatchEvent(new UIComponentEvent(UIComponentEvent.MOVE));		}						/**
		 * Disposes the class.
		 */
		public function dispose():void
		{
		}						//-----------------------------------------------------------------------------------------
		// Accessors
		//-----------------------------------------------------------------------------------------				/**		 * Retrieves the default style map for the current component. The style map contains		 * the type that is appropriate for the component, depending on the style that the		 * component uses. For example, the <code>disabledTextFormat</code> style contains a		 * value of <code>null</code> or a TextFormat object. You can use these styles and		 * call <code>setStyle()</code> on the current component. The following code		 * overrides the default <code>disabledTextFormat</code> style on the specified		 * component: <listing>componentInstance.setStyle("disabledTextFormat", new		 * TextFormat());</listing>		 * 		 * @return Default styles object.		 */		public static function get styleDefinition():Object		{						return _defaultStyles;		}						/**		 * Gets or sets the FocusManager that controls focus for this component and its		 * peers. Each pop-up component maintains its own focus loop and FocusManager		 * instance. Use this property to access the correct FocusManager for this		 * component.		 * 		 * @return The FocusManager that is associated with the current component; otherwise		 *         this property returns <code>null</code>.		 */		public function get focusManager():IFocusManager		{			var d:DisplayObject = this;			while (d) 			{				if (UIComponent._focusManagers[d])				{					return IFocusManager(UIComponent._focusManagers[d]);				}				d = d.parent;			}			return null;		}		public function set focusManager(v:IFocusManager):void		{			UIComponent._focusManagers[this] = v;		}						/**		 * Gets or sets a value that indicates whether the component can accept user		 * interaction. A value of <code>true</code> indicates that the component can accept		 * user interaction; a value of <code>false</code> indicates that it cannot.		 * <p>		 * If you set the <code>enabled</code> property to <code>false</code>, the color of		 * the container is dimmed and user input is blocked (with the exception of the		 * Label and ProgressBar components).</p>		 */		public function get enabled():Boolean		{			return _isEnabled;		}		public function set enabled(v:Boolean):void		{			if (v == _isEnabled) return;			_isEnabled = v;			invalidate(InvalidationType.STATE);		}						/**		 * Gets or sets a value that indicates whether the current component instance is		 * visible. A value of <code>true</code> indicates that the current component is		 * visible; a value of <code>false</code> indicates that it is not.		 * <p>		 * When this property is set to <code>true</code>, the object dispatches a		 * <code>show</code> event. When this property is set to <code>false</code>, the		 * object dispatches a <code>hide</code> event. In either case, the children of the		 * object do not generate a <code>show</code> or <code>hide</code> event unless the		 * object specifically writes an implementation to do so.</p>		 * 		 * @see #event:hide		 * @see #event:show		 */		override public function get visible():Boolean		{			return super.visible;			}		override public function set visible(v:Boolean):void		{			if (v == super.visible) return; 			super.visible = v;			var t:String = (v) ? UIComponentEvent.SHOW : UIComponentEvent.HIDE;			dispatchEvent(new UIComponentEvent(t, true));		}						/**		 * Gets or sets the width of the component, in pixels.		 * <p>		 * Setting this property causes a <code>resize</code> event to be dispatched. See		 * the <code>resize</code> event for detailed information about when it is		 * dispatched.		 * </p>		 * <p>		 * If the <code>scaleX</code> property of the component is not 1.0, the width of the		 * component that is obtained from its internal coordinates will not match the width		 * value from the parent coordinates. For example, a component that is 100 pixels in		 * width and has a <code>scaleX</code> of 2 has a value of 100 pixels in the parent,		 * but internally stores a value indicating that it is 50 pixels wide.		 * </p>		 * 		 * @see #height		 * @see #event:resize		 */		override public function get width():Number		{			return _width;		}		override public function set width(v:Number):void		{			if (v == _width) return;			setSize(v, height);		}						/**		 * Gets or sets the height of the component, in pixels.		 * <p>		 * Setting this property causes a <code>resize</code> event to be dispatched. See		 * the <code>resize</code> event for detailed information about when it is		 * dispatched.		 * </p>		 * <p>		 * If the <code>scaleY</code> property of the component is not 1.0, the height of		 * the component that is obtained from its internal coordinates will not match the		 * height value from the parent coordinates. For example, a component that is 100		 * pixels in height and has a <code>scaleY</code> of 2 has a value of 100 pixels in		 * the parent, but internally stores a value indicating that it is 50 pixels in		 * height.		 * </p>		 */		override public function get height():Number		{			return _height;		}		override public function set height(v:Number):void		{			if (v == _height) return;			setSize(width, v);		}						/**		 * Gets or sets the x coordinate that represents the position of the component along		 * the x axis within its parent container. This value is described in pixels and is		 * calculated from the left.		 * <p>		 * Setting this property causes the <code>ComponentEvent.MOVE</code> event to be		 * dispatched.		 * </p>		 * 		 * @see #move()		 * @see #y		 */		override public function get x():Number		{			return (isNaN(_x)) ? super.x : _x;		}		override public function set x(v:Number):void		{			move(v, _y);		}						/**		 * Gets or sets the y coordinate that represents the position of the component along		 * the y axis within its parent container. This value is described in pixels and is		 * calculated from the top.		 * <p>		 * Setting this property causes the <code>move</code> event to be dispatched.		 * </p>		 * 		 * @see #move()		 * @see #x		 */		override public function get y():Number		{			return (isNaN(_y)) ? super.y : _y;		}		override public function set y(v:Number):void		{			move(_x, v);		}						/**		 * Multiplies the current width of the component by a scale factor.		 *		 * @see #scaleY		 */		override public function get scaleX():Number		{			return width / _startWidth;		}		override public function set scaleX(v:Number):void		{			setSize(_startWidth * v, height);		}						/**		 * Multiplies the current height of the component by a scale factor.		 *		 * @see #scaleX		 */		override public function get scaleY():Number		{			return height / _startHeight;		}		override public function set scaleY(v:Number):void		{			setSize(width, _startHeight * v);		}						/**		 * Gets or sets a Boolean value that indicates whether the component can receive		 * focus after the user clicks it. A value of <code>true</code> indicates that it		 * can receive focus; a value of <code>false</code> indicates that it cannot.		 * <p>		 * If this property is <code>false</code>, focus is transferred to the first parent		 * whose <code>mouseFocusEnabled</code> property is set to <code>true</code>.		 * </p>		 * 		 * @see #mouseFocusEnabled		 */		public function get focusEnabled():Boolean		{			return _focusEnabled;		}		public function set focusEnabled(v:Boolean):void		{			_focusEnabled = v;		}						/**		 * Gets or sets a value that indicates whether the component can receive focus after		 * the user clicks it. A value of <code>true</code> indicates that it can receive		 * focus; a value of <code>false</code> indicates that it cannot.		 * <p>		 * If this property is <code>false</code>, focus is transferred to the first parent		 * whose <code>mouseFocusEnabled</code> property is set to <code>true</code>.		 * </p>		 * 		 * @see #focusEnabled		 */		public function get mouseFocusEnabled():Boolean		{			return _mouseFocusEnabled;		}		public function set mouseFocusEnabled(v:Boolean):void		{			_mouseFocusEnabled = v;		}						/**		 * @private		 */		public function get useSkin():Boolean		{			return _isUsingSkin;		}		public function set useSkin(v:Boolean):void		{			_isUsingSkin = v;			invalidate(InvalidationType.STYLES);		}						/**		 * Can be set to true to debug components.		 * 		 * @default false		 */		public function get debug():Boolean		{			return _debug;		}		public function set debug(v:Boolean):void		{			_debug = v;		}						//-----------------------------------------------------------------------------------------
		// Callback Handlers
		//-----------------------------------------------------------------------------------------				/**		 * @private		 */		protected function onFocusIn(e:FocusEvent):void		{			if (isOurFocus(DisplayObject(e.target)))			{				var fm:IFocusManager = focusManager;				if (fm && fm.showFocusIndicator)				{					drawFocus(true);					_isFocused = true;				}			}		}						/**		 * @private		 */		protected function onFocusOut(e:FocusEvent):void		{			if (isOurFocus(DisplayObject(e.target)))			{				drawFocus(false);				_isFocused = false;			}		}						/**		 * Abstract Method.		 * @private		 */		protected function onKeyFocusDown(e:KeyboardEvent):void		{		}
		
		/**		 * Abstract Method.		 * @private		 */		protected function onKeyFocusUp(e:KeyboardEvent):void		{		}						/**		 * @private		 */		private function onAddedToStage(e:Event):void		{			removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);			initFocusManager();		}						/**		 * @private		 */		private function onCallLater(e:Event):void		{			if (e.type == Event.ADDED_TO_STAGE)			{				removeEventListener(Event.ADDED_TO_STAGE, onCallLater);								/* now we can listen for render event */				stage.addEventListener(Event.RENDER, onCallLater, false, 0, true);				stage.invalidate();				return;			}			else			{				EventDispatcher(e.target).removeEventListener(Event.RENDER, onCallLater);								if (!stage)				{					/* received render, but the stage is not available,					 * so we will listenfor addedToStage again */					addEventListener(Event.ADDED_TO_STAGE, onCallLater, false, 0, true);					return;				}			}						isCallLaterPhase = true;						var methods:Dictionary = _callLaterMethods;			for (var m:Object in methods)			{				/*FDT_IGNORE*/				m();				/*FDT_IGNORE*/				delete(methods[m]);			}						isCallLaterPhase = false;		}						//-----------------------------------------------------------------------------------------
		// Private Methods
		//-----------------------------------------------------------------------------------------				/**		 * @private		 */		protected function getScaleY():Number		{			return super.scaleY;		}						/**		 * @private		 */		protected function setScaleY(v:Number):void		{			super.scaleY = v;		}						/**		 * @private		 */		protected function getScaleX():Number		{			return super.scaleX;		}						/**		 * @private		 */		protected function setScaleX(v:Number):void		{			super.scaleX = v;		}						/**		 * @private		 */		protected function configUI():void		{			var r:Number = rotation;			rotation = 0;			var w:Number = super.width;			var h:Number = super.height;			super.scaleX = super.scaleY = 1;			setSize(w, h);			move(super.x, super.y);			rotation = r;			_startWidth = w;			_startHeight = h;						if (numChildren > 0)			{				removeChildAt(0);			}		}						/**		 * @private		 */		protected function callLater(f:Function):void		{			if (isCallLaterPhase) return;						_callLaterMethods[f] = true;						if (stage)			{				stage.addEventListener(Event.RENDER, onCallLater, false, 0, true);				stage.invalidate();			}			else			{				addEventListener(Event.ADDED_TO_STAGE, onCallLater, false, 0, true);			}		}						/**		 * @private		 */		protected function draw():void		{			/* classes that extend UIComponent should deal with each possible			 * invalidated property common values include all, size, enabled, styles,			 * state. draw should call super or validate when finished updating. */			if (isInvalid(InvalidationType.SIZE, InvalidationType.STYLES))			{				if (_isFocused && focusManager.showFocusIndicator)				{					drawFocus(true);				}			}			validate();		}						/**		 * Included the first property as a proper param to enable *some* type checking, and		 * also because it is a required param.		 * 		 * @private		 * @param p property		 * @param props properties		 */		protected function isInvalid(p:String, ...props:Array):Boolean		{			if (_invalidHash[p] || _invalidHash[InvalidationType.ALL])			{				return true;			}						while (props.length > 0)			{				if (_invalidHash[props.pop()])				{					return true;				}			}			return false;		}						/**		 * @private		 */		protected function validate():void		{			_invalidHash = {};		}						/**		 * @private		 */		protected function getDisplayObjectInstance(skin:Object):DisplayObject		{			var classDef:Object = null;						if (skin is Class)			{				return DisplayObject(new skin());			}			else if (skin is DisplayObject)			{				(skin as DisplayObject).x = 0;				(skin as DisplayObject).y = 0;				return skin as DisplayObject;			}						try			{				/* CAUTION! Not good! Anytime the package is changed, the hard-coded				 * string leads to a headache-causing exception! So far we leave it				 * like this for performance reasons. */				var s:String = UIStyles.THEME_PATH + skin['toString']();				classDef = getDefinitionByName(s);			}			catch (err1:Error)			{				try				{					classDef = loaderInfo.applicationDomain.getDefinition(s) as Object;				}				catch (err2:Error)				{					if (_debug)					{						HLog.warn("UIComponent: " + err2.message + " (Class definition was: "							+ s + ").");					}				}			}						if (!classDef) return null;			return (new classDef()) as DisplayObject;		}						/**		 * Returns the specified style for a component, considering all styles set on the		 * global level, component level and instance level.		 * <p>		 * For example, if a component has a style set at the global level to		 * <code>myStyle</code> and you call <code>getStyle("myStyle")</code> on an instance		 * that does not have an instance setting, it returns null. If you call		 * <code>getStyleValue("myStyle")</code>, it returns "myStyle", because it is active		 * at the global level.		 * </p>		 * 		 * @private		 */		protected function getStyleValue(name:String):*		{			return (!_instanceStyles[name]) ? _sharedStyles[name] : _instanceStyles[name];		}						/**		 * @private		 */		protected function isOurFocus(target:DisplayObject):Boolean		{			return (target == this);		}						/**		 * @private		 */		protected function copyStylesToChild(child:UIComponent, styleMap:Object):void		{			for (var n:String in styleMap)			{				child.setStyle(n, getStyleValue(styleMap[n]));			}		}						/**		 * @private		 */		private function initFocusManager():void		{			/* create root FocusManager */			if (!stage)			{				/* we don't have stage yet, wait for it */				addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);			}			else			{				/* we have stage: if not already created, create FocusManager */				createFocusManager();			}		}						/**		 * @private		 */		protected function createFocusManager():void		{			if (!_focusManagers[stage])			{				_focusManagers[stage] = new FocusManager(stage);			}		}	}}