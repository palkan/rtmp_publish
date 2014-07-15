package ru.teachbase.managers {
import flash.events.ActivityEvent;
import flash.events.AsyncErrorEvent;
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.NetStatusEvent;
import flash.media.Camera;
import flash.media.H264VideoStreamSettings;
import flash.media.Microphone;
import flash.media.VideoStreamSettings;
import flash.net.NetConnection;
import flash.net.NetStream;

import ru.teachbase.model.App;
import ru.teachbase.model.PublishParams;

import ru.teachbase.constants.NetStreamStatusCodes;
import ru.teachbase.manage.*;
import ru.teachbase.net.stats.RTMPWatch;
import ru.teachbase.utils.CameraUtils;
import ru.teachbase.utils.MicrophoneUtils;
import ru.teachbase.utils.shortcuts.debug;
import ru.teachbase.utils.shortcuts.error;
import ru.teachbase.utils.shortcuts.warning;
import ru.teachbase.utils.system.requestUserMediaAccess;

/**
 * Base manager for camera and mic sharing.
 *
 *
 * @author palkan (created: Jul 15, 2014)
 */
public class PublishManager extends Manager {

    protected var _stream:NetStream;

    private var _camera:Camera;
    private var _microphone:Microphone;
    private var _connection:NetConnection;

    private var _streaming:Boolean = false;

    private var _h264Settings:H264VideoStreamSettings = new H264VideoStreamSettings();
    private var _videoSettings:VideoStreamSettings = new VideoStreamSettings();

    private var _stream_type:String = '';


    // Very stupid publish handler!!! Don't repeat this shit!
    public var onPublish:Function;

    /**
     *  Create new PublishManager.
     *
     *  @inheritDoc
     */
    public function PublishManager(register:Boolean = false) {
        super(register,[RTMPManager]);
    }

    //------------ initialize ------------//


    override protected function initialize(reinit:Boolean = false):void {

        if (!App.rtmp || !App.rtmp.connected) {
            error("Can not find RTMPManager or RTMPManager is disconnected",1);
            _failed = true;
            return;
        }

        _connection = App.rtmp.connection;

        if(reinit && _stream){
            _streaming = videoSharing = audioSharing = false;
            _stream = null;
        }

        _initialized = true;
    }



    override public function clear():void{

        closeCamera();
        closeAudio();
        _stream = null;
        _streaming = videoSharing = audioSharing = false;
        super.clear();
    }



    //------------- API -----------------//

    /**
     *  Turn camera sharing on or off.
     */

    public function toggleStartCamera():void {
       (videoSharing && closeCamera()) || start(false,true);
    }


    /**
     * Turn mic sharing on/off.
     */

    public function toggleStartAudio():void {
        ((audioSharing &&  closeAudio()) || start(true, false));
    }


    public function startAll():void{
        start(true,true);
    }


    /**
     * Stop camera sharing
     * @return
     */

    public function closeCamera():Boolean {
        if (!videoSharing)
            return false;

        _streaming && _stream.attachCamera(null);
        videoSharing = false;

        _streaming && !audioSharing && _stream.publish(null);

        return true;
    }

    /**
     *
     * Detach audio stream (use when audio stream only!)
     *
     * @return
     */

    public function closeAudio():Boolean {
        if (!audioSharing)
            return false;

        _streaming && _stream.attachAudio(null);
        audioSharing = false;

        _streaming && !videoSharing && _stream.publish(null);
        return true;
    }


    /**
     * Close sharing
     */

    public function closeAll():void {
        closeCamera();
        closeAudio();
    }


    /**
     *
     */

    public function updateMicrophone():void{

        setMicrophone(true);

        if(audioSharing) _stream.attachAudio(_microphone);

    }


    /**
     *
     *
     */

    public function updateCamera():void{

        setCamera(true);

        if(videoSharing){

            _stream.attachCamera(null);
            _stream.attachCamera(_camera);
        }

    }



    public function setCamQuality():void{
        if(!_camera) return;

        if(params.h264) _stream && (_stream.videoStreamSettings = _h264Settings);
        else _stream && (_stream.videoStreamSettings = _videoSettings);

        _camera.setKeyFrameInterval(params.kfi);
        _camera.setMode(params.width,params.height,params.fps);
        _camera.setQuality(params.bandwidth,params.quality);
    }


    public function setMicQuality():void{
        if(!_microphone) return;
        MicrophoneUtils.configure(_microphone,params.audioCodec, params.audioRate, params.encodeQuality, params.fpp, params.gain, params.silenceLevel);
    }

    //------------- API ----------------//

    /**
     *
     * Initialize camera
     *
     * @param force If <code>true</code> - re-initialize
     */

    private function setCamera(force:Boolean = false):void{

        if (_camera && !force) return;

        _camera = CameraUtils.getCamera();

        debug("Switched to camera: " + (_camera ? _camera.name : "none"));

        if (!_camera) return;

        setCamQuality();

        _camera.setLoopback(true);
    }


    /**
     * Initialize microphone
     *
     * @param force If <code>true</code> - re-initialize
     */

    private function setMicrophone(force:Boolean = false):void{
        if(_microphone && !force) return;

        _microphone = MicrophoneUtils.getMicrophone(-1,true);

        debug("Switched to microphone: " + (_microphone ? _microphone.name : "none"));

        setMicQuality();
    }

    /**
     *
     * Start sharing
     *
     * @param audio
     * @param video
     */

    private function start(audio:Boolean = true, video:Boolean = true):void {
        if ((!audio && !video))
            return;

        // if we are streaming then do not need to check permissions

        _streaming && success(false);

        // ask for media access permissions and then publish

        !_streaming && requestUserMediaAccess(-1, -1, success, failure, App.stage);

        function success(status:Boolean):void{

            // create NetStream object if needed

            initStream();

            // if we need audio

            audio && startAudioSharing();

            // if we need video

            video && startVideoSharing();

            // when we starting to publish we wait 'till NetStatus.Publish.Success event to update User model

            if(!_streaming && (videoSharing || audioSharing)){
                var _stream_name:String = 'stream'+(new Date()).getTime();

                debug('Stream created: '+_stream_name +'('+params.type+')');

                _stream.client.data = {name: _stream_name};
                _stream.publish(_stream_name, params.type);
                _streaming = true;
            }

        }

        function failure(error:String):void {
            warning("media access error:",error);
            audioSharing = videoSharing = false;
        }


    }

    private function startAudioSharing():void {

        setMicrophone(true);
        if (_microphone){
            _stream.attachAudio(null);
            _stream.attachAudio(_microphone);
            audioSharing = true;
        } else
            audioSharing = false;

    }


    private function startVideoSharing():void {

        setCamera(true);

        if (_camera) {

            _stream.attachCamera(_camera);

            videoSharing = true;

        } else
            videoSharing = false;

    }


    private function camActiveHandler(e:ActivityEvent):void {
        if (e.activating) {
            _camera.removeEventListener(ActivityEvent.ACTIVITY, camActiveHandler);
            _stream.attachCamera(null);
            _stream.attachCamera(_camera);
        }
    }

    protected function initStream():void {
        if (!_stream) {
            _stream = new NetStream(App.rtmp.connection);

            var ns_client:Object = {};
            ns_client.onMetaData = function (metadata:Object):void {
                //nothing to do
            };
            _stream.client = ns_client;
            _stream.addEventListener(NetStatusEvent.NET_STATUS, streamStatusHandler);
            _stream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, streamErrorHandler);
            _stream.addEventListener(IOErrorEvent.IO_ERROR, streamErrorHandler);
            _stream.bufferTime = 0;

            if(params.h264) _stream && (_stream.videoStreamSettings = _h264Settings);
            else _stream && (_stream.videoStreamSettings = _videoSettings);
        }
    }


    protected function streamLooksDeadHandler(e:Event):void{

        const _watcher:RTMPWatch = e.target as RTMPWatch;

        _watcher.removeEventListener(Event.CLEAR,  streamLooksDeadHandler);

        warning("Publish failed: empty stream");
        closeAll();

    }


    protected function streamErrorHandler(e:ErrorEvent):void {
        warning("Publish failed: ", e.text);
        _streaming = false;
        closeAll();
    }

    protected function streamStatusHandler(e:NetStatusEvent):void {

        debug("Publish: ",e.info.code);

        switch(e.info.code){
            case NetStreamStatusCodes.PUBLISH_START:{
                this.onPublish && this.onPublish(e.target.client.data.name);
                break;
            }
            case NetStreamStatusCodes.UNPUBLISH_SUCCESS:{
                videoSharing = audioSharing = false;
                _stream.close();
                _streaming  = false;
                break;
            }
            case NetStreamStatusCodes.FAILED:{
                warning("Publish failed");
                _streaming = false;
                closeAll();
                break;
            }
        }
    }



    //----------- getter/setter --------------//


    public function get audioSharing():Boolean {
        return params.audioSharing;
    }

    public function set audioSharing(value:Boolean):void {
        params.audioSharing = value;
    }

    public function get videoSharing():Boolean {
        return params.videoSharing;
    }

    public function set videoSharing(value:Boolean):void {
        params.videoSharing = value;
    }

    public function get params():PublishParams{
        return App.params;
    }

    public function get microphone():Microphone {
        return _microphone;
    }

    public function get camera():Camera {
        return _camera;
    }

    public function get stream_data():Object {
        if(_stream){
            return _stream.client.data;
        }
        return null;
    }

}

}
