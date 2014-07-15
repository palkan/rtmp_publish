/**
 * User: palkan
 * Date: 8/15/13
 * Time: 2:42 PM
 */
package ru.teachbase.managers {
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.NetStatusEvent;
import flash.net.NetConnection;

import ru.teachbase.constants.NetConnectionStatusCodes;
import ru.teachbase.events.ErrorCodeEvent;
import ru.teachbase.manage.*;
import ru.teachbase.net.factory.ConnectionFactory;
import ru.teachbase.net.factory.FactoryErrorCodes;
import ru.teachbase.net.stats.NetworkStats;
import ru.teachbase.utils.shortcuts.config;
import ru.teachbase.utils.shortcuts.debug;
import ru.teachbase.utils.shortcuts.error;

/**
 *
 * Creates and controls NetConnection for NetStreams only.
 *
 */

public class RTMPManager extends Manager {

    private var _connection:NetConnection;

    private var _factory:ConnectionFactory = new ConnectionFactory();

    private var _stats:NetworkStats;

    private var _host:String;

    public function RTMPManager(register:Boolean = false){
        _host = config('rtmp_url');
        super(register);
    }

    override protected function initialize(reinit:Boolean = false):void{

        if(!_host){
            error("Missing RTMP stream options",1);
            _failed = true;
            return;
        }

        initConnection();

    }


    private function initConnection():void{
        _factory.ng.addEventListener(ErrorEvent.ERROR, connectionErrorHandler);
        _factory.ng.addEventListener(Event.COMPLETE, connectionCreatedHandler);
        _factory.createConnection(_host);
    }



    // --------- API (Begin) --------- //


    /**
     * @inherit
     */

    override public function clear():void{
        super.clear();
        if(connected){
            _connection.removeEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
            _connection.close();
        }
        _connection = null;
    }


    /**
     * Close current connection and reconnect to new host if url is provided and to the same host otherwise
     * @param url
     */

    public function reconnect(url:String = ''):void{
        clear();
        _host = url || _host;
        initConnection();
    }



    // ---------- API (End) ---------- //


    protected function connectionErrorHandler(e:ErrorCodeEvent):void {
        switch(e.code){
            case FactoryErrorCodes.FAILED:
                error('Connection failed',1);
                break;
            case FactoryErrorCodes.TIMEOUT:
                error('Connection timeout',1);
                break;
            case FactoryErrorCodes.REJECTED:
                error(e.text,1);
                break;
        }
        _failed = true;
        removeFactoryListeners();
    }

    protected function connectionCreatedHandler(e:Event):void {
        _connection = _factory.connection;
        removeFactoryListeners();
        setupConnection();
        if(!_stats) _stats = new NetworkStats();


        function statsInited(e:Event){
            _stats.removeEventListener(Event.COMPLETE, statsInited);
            _stats.removeEventListener(ErrorEvent.ERROR, statsFailed);
            _initialized = true;
        }

        function statsFailed(e:ErrorEvent){
            _stats.removeEventListener(ErrorEvent.ERROR, statsFailed);
            _stats.removeEventListener(Event.COMPLETE, statsInited);
            _failed = true;
        }

        _stats.addEventListener(Event.COMPLETE, statsInited);

        _stats.addEventListener(ErrorEvent.ERROR, statsFailed);

        _stats.initialize(_connection);
    }

    private function setupConnection():void{
        _connection.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
        _connection.client = {};
    }


    /**
     *  Active NetConnection
     */

    public function get connection():NetConnection {
        return _connection;
    }

    public function get connected():Boolean{
        return _connection && _connection.connected;
    }


    private function removeFactoryListeners():void{
        _factory.removeEventListener(ErrorEvent.ERROR, connectionErrorHandler);
        _factory.removeEventListener(Event.COMPLETE, connectionCreatedHandler);
    }

    protected function netStatusHandler(e:NetStatusEvent):void {

        debug("[rtmp media] NetStatus: "+e.info.code);

        switch(e.info.code){
            case NetConnectionStatusCodes.REJECTED:
                _initialized = false;
                error(e.info.text,1);
                break;
            case NetConnectionStatusCodes.CLOSED:
                initialized && error('Connection dropped',1);
                _initialized = false;
                break;
        }

    }

    public function get stats():NetworkStats {
        return _stats;
    }
}
}
