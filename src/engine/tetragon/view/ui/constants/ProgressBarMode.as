package tetragon.view.ui.constants
{
	/**
	 * The ProgressBarMode class defines the values for the <code>mode</code> 
	 * property of the ProgressBar class.
	 *
	 * @see ProgressBar#mode ProgressBar.mode
	 */
	public class ProgressBarMode
	{
		/**
		 * Manually update the status of the ProgressBar component. In this mode, you specify the 
		 * <code>minimum</code> and <code>maximum</code> properties and use the 
		 * <code>setProgress()</code> method to specify the status.
		 *
		 * @see ProgressBar#maximum ProgressBar.maximum
		 * @see ProgressBar#minimum ProgressBar.minimum
		 * @see ProgressBar#setProgress() ProgressBar.setProgress()
		 */
		public static const MANUAL:String = "manual";
		
		
		/**
		 * The component specified by the <code>source</code> property must dispatch 
		 * <code>progress</code> and <code>complete</code> 
		 * events. The ProgressBar uses these events to update its status.
		 *
		 * @see fl.containers.ScrollPane#event:complete ScrollPane complete event
		 * @see fl.containers.ScrollPane#event:progress ScrollPane progress event
		 * @see fl.containers.UILoader#event:complete UILoader complete event
		 * @see fl.containers.UILoader#event:progress UILoader progress event
		 * @see flash.display.LoaderInfo#event:complete LoaderInfo complete event
		 * @see flash.display.LoaderInfo#event:progress LoaderInfo progress event
		 * @see flash.media.Sound#event:complete Sound complete event
		 * @see flash.media.Sound#event:progress Sound progress event
		 * @see flash.net.FileReference#event:complete FileReference complete event
		 * @see flash.net.FileReference#event:progress FileReference progress event
		 * @see flash.net.URLLoader#event:complete URLLoader complete event
		 * @see flash.net.URLLoader#event:progress URLLoader progress event
		 * @see flash.net.URLStream#event:complete URLStream complete event
		 * @see flash.net.URLStream#event:progress URLStream progress event
		 */
		public static const EVENT:String = "event";
		
		
		/**
		 * Progress is updated by polling the source. The <code>source</code> 
		 * property must specify an object that exposes the <code>bytesLoaded</code>
		 * and <code>bytesTotal</code> properties.
		 *
		 * @see fl.containers.ScrollPane#bytesLoaded ScrollPane.bytesLoaded
		 * @see fl.containers.ScrollPane#bytesTotal ScrollPane.bytesTotal
		 * @see fl.containers.UILoader#bytesLoaded UILoader.bytesLoaded
		 * @see fl.containers.UILoader#bytesTotal UILoader.bytesTotal
		 * @see flash.media.Sound#bytesLoaded Sound.bytesLoaded
		 * @see flash.media.Sound#bytesTotal Sound.bytesTotal
		 * @see flash.net.NetStream#bytesLoaded NetStream.bytesLoaded
		 * @see flash.net.NetStream#bytesTotal NetStream.bytesTotal
		 * @see flash.net.URLLoader#bytesLoaded URLLoader.bytesLoaded
		 * @see flash.net.URLLoader#bytesTotal URLLoader.bytesTotal
		 */
		public static const POLLED:String = "polled";
	}
}
