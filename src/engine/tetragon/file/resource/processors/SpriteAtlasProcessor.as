/*
 *      _________  __      __
 *    _/        / / /____ / /________ ____ ____  ___
 *   _/        / / __/ -_) __/ __/ _ `/ _ `/ _ \/ _ \
 *  _/________/  \__/\__/\__/_/  \_,_/\_, /\___/_//_/
 *                                   /___/
 * 
 * Tetragon : Game Engine for multi-platform ActionScript projects.
 * http://www.tetragonengine.com/ - Copyright (C) 2012 Sascha Balkau
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
package tetragon.file.resource.processors
{
	import tetragon.data.atlas.SpriteAtlas;
	import tetragon.data.atlas.SubTextureBounds;
	import tetragon.file.resource.Resource;
	import tetragon.file.resource.ResourceStatus;

	import flash.display.BitmapData;
	import flash.geom.Rectangle;

	
	
	/**
	 * Processes sprite atlas data so that it is ready for use. This processor parses
	 * through SpriteAtlas resources and generates the single frames of a sprite atlas.
	 */
	public class SpriteAtlasProcessor extends ResourceProcessor
	{
		//-----------------------------------------------------------------------------------------
		// Private Methods
		//-----------------------------------------------------------------------------------------
		
		/**
		 * @inheritDoc
		 */
		override protected function processResources():Boolean
		{
			for (var i:uint = 0; i < resources.length; i++)
			{
				var resource:Resource = resources[i];
				var spriteAtlas:SpriteAtlas = resource.content;
				
				if (!spriteAtlas)
				{
					return false;
				}
				if (spriteAtlas.processed)
				{
					return true;
				}
				if (spriteAtlas.subTextureCount < 1)
				{
					error("Cannot process sprite atlas \"" + spriteAtlas.id
						+ "\" because it has no subtextures defined.");
					continue;
				}
				
				var image:* = resourceIndex.getResourceContent(spriteAtlas.imageID);
				
				if (image is BitmapData)
				{
					spriteAtlas.source = image;
				}
				else if (image == null)
				{
					error("Cannot process sprite atlas \"" + spriteAtlas.id
						+ "\". Required sprite atlas image \"" + spriteAtlas.imageID
						+ "\" is null.");
					continue;
				}
				else
				{
					error("Cannot process sprite atlas \"" + spriteAtlas.id
						+ "\". Required sprite atlas image \"" + spriteAtlas.imageID
						+ "\" is an unsupported format.");
					continue;
				}
				
				processSpriteAtlas(spriteAtlas);
				resource.setStatus(ResourceStatus.PROCESSED);
			}
			return true;
		}
		
		
		/**
		 * Processes a sprite atlas.
		 */
		private function processSpriteAtlas(spriteAtlas:SpriteAtlas):void
		{
			var len:uint = spriteAtlas.subTextureCount;
			for (var i:uint = 0; i < len; i++)
			{
				var b:SubTextureBounds = spriteAtlas.subTextureBounds[i];
				var region:Rectangle = new Rectangle(b.x, b.y, b.width, b.height);
				var frame:Rectangle = b.frameWidth > 0 && b.frameHeight > 0
					? new Rectangle(b.frameX, b.frameY, b.frameWidth, b.frameHeight)
					: null;
				spriteAtlas.addRegion(b.id, region, frame);
			}
			
			spriteAtlas.processed = true;
		}
	}
}
