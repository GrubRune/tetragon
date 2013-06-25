/* * hexagonlib - Multi-Purpose ActionScript 3 Library. *       __    __ *    __/  \__/  \__    __ *   /  \__/HEXAGON \__/  \ *   \__/  \__/  LIBRARY _/ *            \__/  \__/ * * Licensed under the MIT License *  * Permission is hereby granted, free of charge, to any person obtaining a copy of * this software and associated documentation files (the "Software"), to deal in * the Software without restriction, including without limitation the rights to * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of * the Software, and to permit persons to whom the Software is furnished to do so, * subject to the following conditions: *  * The above copyright notice and this permission notice shall be included in all * copies or substantial portions of the Software. *  * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */package tetragon.core.file{	import tetragon.core.file.types.IFile;	import tetragon.core.file.types.SoundFile;	import tetragon.core.signals.Signal;	import tetragon.core.structures.IIterator;	import tetragon.core.structures.queues.Queue;	import tetragon.debug.Log;	import tetragon.util.display.StageReference;	import flash.events.Event;			/**	 * The BulkLoader offers comfortable loading of multiple files.<br>	 * 	 * <p>To use the bulk loader you first have to add file objects to it by using the	 * <code>addFile()</code> method to add single files or the	 * <code>addFileQueue()</code> method to add a queue of files. After that	 * <code>load()</code> is called to start the loading process.</p><br>	 * 	 * <p>Files are loaded one by one unless you increase the amount of concurrent load	 * connections by using the <code>maxConnections</code> property. For example setting	 * <code>maxConnections</code> to 4 will tell the bulk loader to load a maximum of	 * four files at the same time. This can speed up loading of files on a fast network	 * connection.</p><br>	 * 	 * <p>By default any file that failed loading will not tried to be loaded again in the	 * same operation unless the <code>loadRetries</code> property is raised. This	 * property is only meaningful for loading files over a network.</p><br>	 * 	 * <p>If you only need to a load a single file you can opt to use the FileLoader class	 * instead which is more light-weight than the BulkLoader.</p>	 * 	 * @see com.hexagonstar.file.BulkFile	 * @see com.hexagonstar.file.BulkSoundFile	 * @see com.hexagonstar.file.FileLoader	 * @see com.hexagonstar.structures.queues.Queue	 */	public class BulkLoader	{		//-----------------------------------------------------------------------------------------		// Properties		//-----------------------------------------------------------------------------------------				/** @private */		protected var _files:Vector.<BulkFileVO>;		/** @private */		protected var _loadedFileQueue:Queue;		/** @private */		protected var _bulkProgress:BulkProgress;		/** @private */		protected var _usedConnections:Object;		/** @private */		protected var _maxConnections:int;		/** @private */		protected var _loadRetries:int;		/** @private */		protected var _priorityCount:int;		/** @private */		protected var _fileCount:uint;		/** @private */		protected var _filesTotal:uint;		/** @private */		protected var _filesProcessed:uint;		/** @private */		protected var _loading:Boolean;		/** @private */		protected var _aborted:Boolean;		/** @private */		protected var _useAbsoluteFilePath:Boolean;		/** @private */		protected var _preventCaching:Boolean;		/** @private */		protected var _distributedLoading:Boolean;		/** @private */		protected var _useAIRFileAPI:Boolean;		/** @private */		protected var _nextBF:IBulkFile;						//-----------------------------------------------------------------------------------------		// Signals		//-----------------------------------------------------------------------------------------				/** @private */		protected var _fileOpenSignal:Signal;		/** @private */		protected var _fileProgressSignal:Signal;		/** @private */		protected var _fileCompleteSignal:Signal;		/** @private */		protected var _fileHTTPStatusSignal:Signal;		/** @private */		protected var _fileIOErrorSignal:Signal;		/** @private */		protected var _fileSecurityErrorSignal:Signal;		/** @private */		protected var _fileAbortSignal:Signal;		/** @private */		protected var _allCompleteSignal:Signal;						//-----------------------------------------------------------------------------------------		// Constructor		//-----------------------------------------------------------------------------------------				/**		 * Creates a new bulk loader instance.		 * 		 * @param maxConnections Maximum concurrent load connections.		 * @param loadRetries How often a failed file should be retried to be loaded.		 * @param useAbsoluteFilePath If true absolute file paths are used.		 * @param preventCaching If true the loader adds a timestamp to the file path to		 *            prevent file caching by server caches or proxies.		 * @param useAIRFileAPI		 */		public function BulkLoader(maxConnections:int = 1, loadRetries:int = 0,			useAbsoluteFilePath:Boolean = false, preventCaching:Boolean = false,			useAIRFileAPI:Boolean = false)		{			this.maxConnections = maxConnections;			this.loadRetries = loadRetries;			_useAbsoluteFilePath = useAbsoluteFilePath;			_preventCaching = preventCaching;			_distributedLoading = false;			this.useAIRFileAPI = useAIRFileAPI;						reset();		}						//-----------------------------------------------------------------------------------------		// Public Methods		//-----------------------------------------------------------------------------------------				/**		 * Resets the loader. You only need to call this method if you want to use the same		 * loader instance more than once. You cannot reset the loader while it's performing		 * a load operation.		 */		public function reset():void		{			if (_loading)			{				Log.warn("Tried to reset loader during a load operation.", this);				return;			}						_files = new Vector.<BulkFileVO>();			if (_loadedFileQueue) _loadedFileQueue.clear();			else _loadedFileQueue = new Queue();			_usedConnections = {};			_bulkProgress = null;			_priorityCount = _fileCount = _filesTotal = 0;			_loading = false;			_aborted = false;		}						/**		 * Adds a file to the loader.<br>		 * 		 * <p>If the file has no priority defined (i.e. it's priority is <code>NaN</code>) the		 * loader will automatically assign a priority to the file starting from 0 and		 * counting minus. For example adding three files without priority results in that the		 * first file receives a priority of 0, the second a priority of -1, the third a		 * priority of -2 and so on (down to <code>int.MIN_VALUE</code>). This guarantees that		 * priority-less files are loaded in the same order they were added.</p>		 * 		 * @see #addFileQueue		 * 		 * @param file The file to add to the loader.		 * @return true if the file was added successfully or false if not, e.g. if a file		 *         with the same path has already been already added to the loader.		 */		public function addFile(file:IFile):Boolean		{			/* We use the file path as the ID to map file objects. */			var id:String = file.path;						/* If file was already added to this bulk, don't add it again! */			//if (isAlreadyAdded(id))			//{			//	HLog.debug(toString() + " The file <" + id + "> has already been added.");			//	return false;			//}						/* If no file priority was defined, assign automatic priority. */			if (isNaN(file.priority))			{				file.priority = _priorityCount;				if (_priorityCount > int.MIN_VALUE) _priorityCount--;			}						var bf:IBulkFile;			if (_useAIRFileAPI)			{				bf = new BulkFileAIR(file);				bf.fileOpenSignal.addOnce(onFileOpen);				bf.fileProgressSignal.add(onFileProgress);				bf.fileIOErrorSignal.addOnce(onFileError);				bf.fileCompleteSignal.addOnce(onFileComplete);			}			else			{				if (file is SoundFile) bf = new BulkSoundFile(file);				else bf = new BulkFile(file);				bf.fileOpenSignal.addOnce(onFileOpen);				bf.fileProgressSignal.add(onFileProgress);				bf.fileHTTPStatusSignal.addOnce(onHTTPStatus);				bf.fileIOErrorSignal.addOnce(onFileError);				bf.fileSecurityErrorSignal.addOnce(onFileError);				bf.fileCompleteSignal.addOnce(onFileComplete);			}						var vo:BulkFileVO = new BulkFileVO(id, file.priority, bf);						_files.push(vo);			_fileCount = _filesTotal += 1;						return true;		}						/**		 * Allows adding a queue of files at once to the loader. The enqueued files must be of		 * type IFile. Any non-IFile objects in the queue are ignored. It is possible to add		 * several queues to the loader.		 * 		 * @see #addFile		 * @see com.hexagonstar.structures.queues.Queue		 * 		 * @param queue The queue with files to load.		 */		public function addFileQueue(queue:Queue):void		{			if (!queue) return;			var i:IIterator = queue.iterator;			while (i.hasNext)			{				var n:* = i.next;				if (n is IFile)				{					addFile(n);				}				else				{					Log.warn("File queue contains item which is not of type IFile: " + n, this);				}			}		}						/**		 * Starts loading the files which were added to the loader with <code>addFile()</code>		 * or <code>addFileQueue()</code>.		 * 		 * @see #addFile		 * @see #addFileQueue		 * 		 * @return <code>true</code> if the load process started or <code>false</code> if the		 *         loader is already loading or the file count is zero.		 */		public function load():Boolean		{			if (_loading || _fileCount < 1) return false;						_filesProcessed = 0;			_aborted = false;			_loading = true;						sort();			loadNext();						return true;		}						/**		 * Aborts the bulk load process. Aborting only takes effect between files in the bulk		 * and never while a file is loaded. I.e. if you call abort while a file in the bulk		 * is currently being loaded the loader will finish loading the current file in		 * progress and aborts once the file is loaded but before the next file in the load		 * queue. Calling abort before the first file is loaded or after the last file started		 * loading has no effect.		 */		public function abort():void		{			if (!_loading || _fileCount < 1) return;			_aborted = true;		}						/**		 * Provides a shortcut method for adding IO event listeners quickly. The class which		 * should listen to events fired by this loader needs to implement the		 * IFileIOEventListener interface if it is used with this method.		 * 		 * @see com.hexagonstar.file.IFileIOEventListener		 * @see #removeEventListenersFor		 * 		 * @param listener The listener which should listen for IO events fired by the loader.		 */		public function addListenersFor(listener:IFileIOSignalListener):void		{			fileOpenSignal.add(listener.onFileOpen);			fileProgressSignal.add(listener.onFileProgress);			fileCompleteSignal.add(listener.onFileComplete);			fileAbortSignal.add(listener.onFileAbort);			fileHTTPStatusSignal.add(listener.onFileHTTPStatus);			fileIOErrorSignal.add(listener.onFileIOError);			fileSecurityErrorSignal.add(listener.onFileSecurityError);			allCompleteSignal.add(listener.onAllFilesComplete);		}						/**		 * Provides a shortcut method for removing all event listeners that were added before		 * with <code>addEventListenersFor()</code>.		 * 		 * @see com.hexagonstar.file.IFileIOEventListener		 * @see #addEventListenersFor		 * 		 * @param listener The listener which should stop listen for IO events fired by the loader.		 */		public function removeListenersFor(listener:IFileIOSignalListener):void		{			fileOpenSignal.remove(listener.onFileOpen);			fileProgressSignal.remove(listener.onFileProgress);			fileCompleteSignal.remove(listener.onFileComplete);			fileAbortSignal.remove(listener.onFileAbort);			fileHTTPStatusSignal.remove(listener.onFileHTTPStatus);			fileIOErrorSignal.remove(listener.onFileIOError);			fileSecurityErrorSignal.remove(listener.onFileSecurityError);			allCompleteSignal.remove(listener.onAllFilesComplete);		}						/**		 * Disposes the loader to free up system resources. The loader instance cannot be		 * used anymore after calling this method unless <code>reset()</code> is called		 * afterwards. Note that you cannot dispose the loader while it performs a load		 * operation. You first need to make sure that all loading stopped.		 */		public function dispose():void		{			if (_loading) return;						for (var i:uint = 0; i < _fileCount; i++)			{				removeListenersFrom(_files[i].bulkfile);				_files[i].bulkfile.dispose();			}						_files = null;			_usedConnections = null;			_priorityCount = _fileCount = _filesTotal = 0;		}						/**		 * Returns a string representation of the loader.		 * 		 * @return A string representation of the loader.		 */		public function toString():String		{			return "[BulkLoader]";		}						//-----------------------------------------------------------------------------------------		// Getters & Setters		//-----------------------------------------------------------------------------------------				/**		 * The maximum concurrent load connections. The maximum value is 1000, the minimum		 * value is 1. The default value is 1. Raising this value can increase loading speed		 * of files when loaded over a fast network connection.		 */		public function get maxConnections():int		{			return _maxConnections;		}		public function set maxConnections(v:int):void		{			_maxConnections = (v < 1) ? 1 : (v > 1000) ? 1000 : v;		}						/**		 * Determines how often a file that failed loading should be tried to load again. The		 * default value is 0. This property is only meaningful for loading files over a		 * network connection where file loading might fail due to network problems. The		 * maximum value for this is 1000, the minimum value is 0.		 */		public function get loadRetries():int		{			return _loadRetries;		}		public function set loadRetries(v:int):void		{			_loadRetries = (v < 0) ? 0 : (v > 1000) ? 1000 : v;		}						/**		 * Indicates whether the loader is currently in a load operation or not.		 */		public function get loading():Boolean		{			return _loading;		}						/**		 * Indicates whether the loader was aborted (i.e. <code>abort()</code> was called).		 */		public function get aborted():Boolean		{			return _aborted;		}						/**		 * Determines how many files are left that need to be loaded.		 */		public function get fileCount():uint		{			return _fileCount;		}						/**		 * A Queue that contains all files. This can be used to obtain all files		 * at once after loading of all files has completed. The queue contains		 * both successfully and failed to load files. The queue becomes unavailable		 * after a call to reset().		 */		public function get fileQueue():Queue		{			return _loadedFileQueue;		}						/**		 * Determines whether the loader is using absolute file paths for loading or not.<br>		 * 		 * <p>By default the loader uses the relative file path of any files added for		 * loading. This means the path is relative from the path in that the loading SWF file		 * resides. If <code>useAbsoluteFilePath</code> is set to true the loader will load		 * files by using their full paths. It is recommended to leave this property set to		 * false (the default) unless the server or environment requires absolute file		 * paths.</p>		 */		public function get useAbsoluteFilePath():Boolean		{			return _useAbsoluteFilePath;		}		public function set useAbsoluteFilePath(v:Boolean):void		{			_useAbsoluteFilePath = v;		}						/**		 * Determines whether the loader is preventing file caching (true) or not (false). If		 * set to true the loader will not re-use files cached by a browser or proxy but		 * instead request the files again from the server. The default value is false.		 */		public function get preventCaching():Boolean		{			return _preventCaching;		}		public function set preventCaching(v:Boolean):void		{			_preventCaching = v;		}						/**		 * Determines if loading and processing of files should be distributed over		 * several frames. This can help reducing display freezing in case files are		 * loaded that need to be processed (for example decoded or decompressed) where		 * the display might freeze during CPU-intensive operations. If this property is		 * set to <code>true</code> one file is loaded and processed per frame, then the		 * next file is loaded and processed on the next frame and so on.		 * 		 * @default <code>false</code>		 */		public function get distributedLoading():Boolean		{			return _distributedLoading;		}		public function set distributedLoading(v:Boolean):void		{			_distributedLoading = v;		}						/**		 * Determines whether the loader uses web loading API (URLLoader, false) or the		 * AIR File API (File, true) when loading files.		 * 		 * @default false		 */		public function get useAIRFileAPI():Boolean		{			return _useAIRFileAPI;		}		public function set useAIRFileAPI(v:Boolean):void		{			_useAIRFileAPI = v;		}						/**		 * Signal that is dispatched when a file has been opened.		 * Listener signature: <code>onBulkFileOpen(file:IFile):void</code>		 */		public function get fileOpenSignal():Signal		{			if (!_fileOpenSignal) _fileOpenSignal = new Signal();			return _fileOpenSignal;		}						/**		 * Signal that is dispatched while loading a file.		 * Listener signature: <code>onBulkFileProgress(progress:BulkProgress):void</code>		 */		public function get fileProgressSignal():Signal		{			if (!_fileProgressSignal) _fileProgressSignal = new Signal();			return _fileProgressSignal;		}						/**		 * Signal that is dispatched when a file has been completed loading.		 * Listener signature: <code>onBulkFileLoaded(file:IFile):void</code>		 */		public function get fileCompleteSignal():Signal		{			if (!_fileCompleteSignal) _fileCompleteSignal = new Signal();			return _fileCompleteSignal;		}						/**		 * Signal that is dispatched when a file load causes a HTTP status.		 * Listener signature: <code>onBulkFileHTTPStatus(file:IFile):void</code>		 */		public function get fileHTTPStatusSignal():Signal		{			if (!_fileHTTPStatusSignal) _fileHTTPStatusSignal = new Signal();			return _fileHTTPStatusSignal;		}						/**		 * Signal that is dispatched when an IO error occurs while loading a file.		 * Listener signature: <code>onBulkFileIOError(file:IFile):void</code>		 */		public function get fileIOErrorSignal():Signal		{			if (!_fileIOErrorSignal) _fileIOErrorSignal = new Signal();			return _fileIOErrorSignal;		}						/**		 * Signal that is dispatched when a Security error occurs while loading a file.		 * Listener signature: <code>onBulkFileSecurityError(file:IFile):void</code>		 */		public function get fileSecurityErrorSignal():Signal		{			if (!_fileSecurityErrorSignal) _fileSecurityErrorSignal = new Signal();			return _fileSecurityErrorSignal;		}						/**		 * Signal that is dispatched when a file load is aborted.		 * Listener signature: <code>onBulkFileAbort():void</code>		 */		public function get fileAbortSignal():Signal		{			if (!_fileAbortSignal) _fileAbortSignal = new Signal();			return _fileAbortSignal;		}						/**		 * Signal that is dispatched when all files have completed loading.		 * Listener signature: <code>onBulkFileAllComplete(file:IFile):void</code>		 */		public function get allCompleteSignal():Signal		{			if (!_allCompleteSignal) _allCompleteSignal = new Signal();			return _allCompleteSignal;		}						/**		 * Determines if a free load connection is currently available.		 * 		 * @private		 */		protected function get connectionAvailable():Boolean		{			return currentlyUsedConnections < _maxConnections;		}						/**		 * The amount of load connections that are currently in use.		 * 		 * @private		 */		protected function get currentlyUsedConnections():int		{			var v:int = 0;			for (var c:String in _usedConnections)			{				v++;			}			return v;		}						/**		 * Determines if all files in the bulk were processed, i.e. if they are loaded		 * successfully or failed because of a load error.		 * 		 * @private		 */		protected function get allFilesProcessed():Boolean
		{			return _filesProcessed == _filesTotal;		}						/**		 * Checks if abort was called.		 * 		 * @private		 */		protected function get isAbort():Boolean		{			if (_aborted && _fileCount > 0)			{				_loading = false;				// TODO Abort Signal should dispatch with current file as argument!				if (_fileAbortSignal) _fileAbortSignal.dispatch();				return true;			}			return false;		}						//-----------------------------------------------------------------------------------------		// Event Handlers		//-----------------------------------------------------------------------------------------				/**		 * @private		 */		protected function onEnterFrame(e:Event):void		{			StageReference.stage.removeEventListener(Event.ENTER_FRAME, onEnterFrame);			loadNext();			if (allFilesProcessed)			{				/* Send an additional progress event after all files are finished!				 * Without this the last load stats would not be accurate. */				onFileProgress(_nextBF);				onAllFilesComplete(_nextBF);			}			_nextBF = null;		}						/**		 * @private		 */		protected function onFileOpen(bf:IBulkFile):void		{			if (_fileOpenSignal) _fileOpenSignal.dispatch(bf.file);		}						/**		 * @private		 */		protected function onFileProgress(bf:IBulkFile):void		{			if (_fileProgressSignal) _fileProgressSignal.dispatch(createBulkProgress(bf));		}						/**		 * @private		 */		protected function onHTTPStatus(bf:IBulkFile):void		{			if (_fileHTTPStatusSignal) _fileHTTPStatusSignal.dispatch(bf.file);		}						/**		 * @private		 */		protected function onFileError(bf:IBulkFile):void		{			removeConnectionFrom(bf);						/* Debug only! */			//HLog.warn(toString() + " error loading: " + bf.toString()			//	+ "\n" + (_loadRetries - bf.retryCount) + " retries left"			//	+ "\nstatus: " + bf.status			//	+ "\nerror message: " + bf.file.errorMessage);						/* Dispatch an error signal here only after all load retries are used up! */			if (bf.retryCount >= _loadRetries)			{				removeListenersFrom(bf);				_loadedFileQueue.enqueue(bf.file);				if (_fileProgressSignal) _fileProgressSignal.dispatch(createBulkProgress(bf));				if (_fileIOErrorSignal) _fileIOErrorSignal.dispatch(bf.file);				if (!isAbort)				{					_filesProcessed++;					next(bf);				}			}			else			{				if (!isAbort)				{					_filesProcessed++;					next(bf);				}				else				{					removeListenersFrom(bf);				}			}		}						/**		 * @private		 */		protected function onFileComplete(bf:IBulkFile):void		{			removeConnectionFrom(bf);			removeListenersFrom(bf);			_loadedFileQueue.enqueue(bf.file);						if (_fileCompleteSignal) _fileCompleteSignal.dispatch(bf.file);			if (!isAbort)			{				_filesProcessed++;				next(bf);			}		}						/**		 * @private		 */		protected function onAllFilesComplete(bf:IBulkFile):void		{			_loading = false;			if (_allCompleteSignal) _allCompleteSignal.dispatch(bf.file);		}						//-----------------------------------------------------------------------------------------		// Private Methods		//-----------------------------------------------------------------------------------------				/**		 * Checks if the file with the specified ID was already added to the bulk.		 * 		 * @private		 */		protected function isAlreadyAdded(id:String):Boolean 		{			for (var i:uint = 0; i < _fileCount; i++)			{				if (_files[i].id == id) return true;			}			return false;		}						/**		 * Sorts the collection of files by priority.		 * 		 * @private		 */		protected function sort():void		{			/* Use nested sort function */			_files.sort(function (o1:BulkFileVO, o2:BulkFileVO):Number			{				if (o1.priority < o2.priority) return 1;				else if (o1.priority > o2.priority) return -1;				return 0;			});		}						/**		 * @private		 */		protected function removeListenersFrom(bf:IBulkFile):void		{			if (bf.fileOpenSignal) bf.fileOpenSignal.remove(onFileOpen);			if (bf.fileProgressSignal) bf.fileProgressSignal.remove(onFileProgress);			if (bf.fileHTTPStatusSignal) bf.fileHTTPStatusSignal.remove(onHTTPStatus);			if (bf.fileIOErrorSignal) bf.fileIOErrorSignal.remove(onFileError);			if (bf.fileSecurityErrorSignal) bf.fileSecurityErrorSignal.remove(onFileError);			if (bf.fileCompleteSignal) bf.fileCompleteSignal.remove(onFileComplete);		}						/**		 * @private		 */		protected function next(bf:IBulkFile):void		{			if (_distributedLoading)			{				_nextBF = bf;				StageReference.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);				return;			}						loadNext();						if (allFilesProcessed)			{				/* Send an additional progress event after all files are finished!				 * Without this the last load stats would not be accurate. */				onFileProgress(bf);				onAllFilesComplete(bf);			}		}						/**		 * @private		 */		protected function loadNext():Boolean		{			var hasNext:Boolean = false;			var next:IBulkFile = getNextBulkFile();						if (next)			{				hasNext = true;				_usedConnections[next.file.path] = true;				next.load(_useAbsoluteFilePath, _preventCaching);								/* If we got any more connections available, go on and load the next item. */				if (getNextBulkFile())				{					loadNext();				}			}						return hasNext;		}						/**		 * @private		 */		protected function getNextBulkFile():IBulkFile		{			for (var i:uint = 0; i < _fileCount; i++)			{				var bf:IBulkFile = _files[i].bulkfile;				if (!bf.loading && bf.status != BulkFile.STATUS_LOADED && connectionAvailable)				{					/* No error status so just load the file. */					if (bf.status != BulkFile.STATUS_ERROR)					{						return bf;					}					else					{						/* There was an error before so check if we still have retries left. */						if (bf.retryCount < _loadRetries)						{							bf.retryCount++;							return bf;						}					}				}			}			return null;		}						/**		 * @private		 */		protected function removeConnectionFrom(bf:IBulkFile):void		{			var id:String = bf.file.path;			for (var i:String in _usedConnections)			{				if (i == id)				{					_usedConnections[i] = false;					delete _usedConnections[i];					return;				}			}		}						/**
		 * @private
		 */
		protected function createBulkProgress(bf:IBulkFile):BulkProgress
		{			if (!_bulkProgress) _bulkProgress = new BulkProgress(_filesTotal);			_bulkProgress.reset();			_bulkProgress._file = bf.file;						var weightLoaded:Number = 0;			var weightTotal:uint = 0;			for (var i:uint = 0; i < _filesTotal; i++)			{				var f:IBulkFile = _files[i].bulkfile;				weightTotal += f.weight;								if (f.status == BulkFile.STATUS_PROGRESSING || f.status == BulkFile.STATUS_LOADED)				{					_bulkProgress._bytesLoaded += f.bytesLoaded;					_bulkProgress._bytesTotal += f.bytesTotal;					if (f.bytesTotal > 0)					{						weightLoaded += (f.bytesLoaded / f.bytesTotal) * f.weight;					}				}								switch (f.status)				{					case BulkFile.STATUS_PROGRESSING:						_bulkProgress._filesLoading++;						break;					case BulkFile.STATUS_LOADED:						_bulkProgress._filesLoaded++;						break;					case BulkFile.STATUS_ERROR:						_bulkProgress._filesFailed++;				}			}			
			if (weightTotal == 0) _bulkProgress._weightedPercentage = 0;			else _bulkProgress._weightedPercentage = weightLoaded / weightTotal;						return _bulkProgress;		}	}}