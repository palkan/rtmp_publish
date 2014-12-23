/**
 * User: palkan
 * Date: 7/15/14
 * Time: 11:54 AM
 */
package ru.teachbase.model {
import flash.media.SoundCodec;

[Bindable]
public class PublishParams {

    public var h264:Boolean = true;
    public var audioCodec:String = SoundCodec.SPEEX;
    public var audioRate:int = 16;
    public var encodeQuality:int = 5;
    public var fpp:int = 2;
    public var gain:int = 100;
    public var silenceLevel:int = 0;

    public var kfi:int = 10;
    public var fps:int = 15;
    public var width:int = 800;
    public var height:int = 600;
    public var bandwidth:int = 0;
    public var bitrate:int = 300;
    public var quality:int = 90;

    public var audioSharing:Boolean = false;
    public var videoSharing:Boolean = false;

    // stream type (record, append, live)

    public var type:String='live';

    public function PublishParams() {
    }
}
}
