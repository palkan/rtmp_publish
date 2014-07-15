/**
 * User: palkan
 * Date: 5/24/13
 * Time: 6:34 PM
 */
package ru.teachbase.controller {
import ru.teachbase.events.AppEvent;

import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.ProgressEvent;
import flash.system.Security;
import flash.utils.setTimeout;

import ru.teachbase.managers.PublishManager;
import ru.teachbase.managers.RTMPManager;

import ru.teachbase.model.App;

import ru.teachbase.events.ErrorCodeEvent;
import ru.teachbase.manage.Initializer;
import ru.teachbase.manage.Manager;
import ru.teachbase.utils.Configger;
import ru.teachbase.utils.GlobalError;
import ru.teachbase.utils.shortcuts.config;
import ru.teachbase.utils.shortcuts.cookie;
import ru.teachbase.utils.shortcuts.debug;


[Event(type="ru.teachbase.events.AppEvent", name="")]

public class ApplicationController extends EventDispatcher {

    private static const REINITIALIZE_INTERVAL:int = 5000;

    protected var _initializing:Boolean = false;

    private var _view:MainApplication;

    private var _reiniting:Boolean = false;

    public function ApplicationController() {
        GlobalError.listen(onGlobalError);
        Configger.loadConfig();
        // update config with cookie data
        cookie('rtmp_url') && config('rtmp_url', cookie('rtmp_url'));
    }

    protected function onGlobalError(e:ErrorCodeEvent):void {
        var errorMessage:String = e.text || 'connection error';

        clear();

        if (App.view && !_initializing && !_reiniting) {
            _reiniting = true;
            debug('Try to reinitialize in 5 seconds');
            setTimeout(reinitialize, REINITIALIZE_INTERVAL);
        }

        if (errorMessage) {
            hasEventListener(AppEvent.CORE_LOAD_ERROR) && dispatchEvent(new AppEvent(AppEvent.CORE_LOAD_ERROR, false, false, errorMessage, true));
            App.view && App.view.failed(errorMessage);
        }
    }


    public function setView(view:MainApplication):void {
        _view = view;
        App.setView(view);
        dispatchEvent(new AppEvent(AppEvent.CORE_LOAD_COMPLETE));
    }


    public function clear():void {

        debug("Dispose session");

        App.rtmp && App.rtmp.clear();
        App.publisher && App.publisher.clear();

    }


    public function initialize():void {

        _initializing = true;

        addInitializerListeners(managersInitializedHandler, managersErrorHandler, managersProgressHandler);

        Initializer.initializeManagers(
                new RTMPManager(true),    // connecting to rtmp server
                new PublishManager(true) // (local) mic/cam publishing
        );
    }


    protected function reinitialize():void {

        debug("[main] init", arguments.callee);

        _initializing = true;

        App.rtmp && App.rtmp.clear();
        App.publisher && App.publisher.clear();

        addInitializerListeners(reinitializationComplete, reinitializationFailed);

        Initializer.reinitializeManagers.apply(null, [App.rtmp || new RTMPManager(true), App.publisher || new PublishManager(true)]);

    }


    protected function reinitializationFailed(e:Event = null):void {

        _initializing = _reiniting = false;
        removeInitializerListeners(reinitializationComplete, reinitializationFailed);
        debug('Reinitialization failed!');
        App.view.failed('Reinitialization failed!');
    }


    protected function reinitializationComplete(e:Event):void {

        _initializing = _reiniting = false;
        removeInitializerListeners(reinitializationComplete, reinitializationFailed);

        debug('Successfully reinitialized');
        App.view.enable();
    }


    protected function managersInitializedHandler(e:Event):void {

        _initializing = false;

        removeInitializerListeners(managersInitializedHandler, managersErrorHandler, managersProgressHandler);

        App.view.enable();
    }

    protected function managersProgressHandler(e:ProgressEvent):void {

        dispatchEvent(new AppEvent(AppEvent.LOADING_STATUS, false, false, "Managers initializing ... " + Math.round(e.bytesLoaded * 100 / e.bytesTotal) + "%"))

    }

    protected function managersErrorHandler(e:ErrorEvent):void {

        _initializing = false;

        removeInitializerListeners(managersInitializedHandler, managersErrorHandler, managersProgressHandler);
        clear();
        _view.failed(e.text);
    }

    protected function addInitializerListeners(complete:Function, failed:Function, progress:Function = null):void {

        Initializer.instance.addEventListener(Event.COMPLETE, complete);
        progress && Initializer.instance.addEventListener(ProgressEvent.PROGRESS, progress);
        Initializer.instance.addEventListener(ErrorEvent.ERROR, failed);

    }

    protected function removeInitializerListeners(complete:Function, failed:Function, progress:Function = null):void {

        Initializer.instance.removeEventListener(Event.COMPLETE, complete);
        progress && Initializer.instance.removeEventListener(ProgressEvent.PROGRESS, progress);
        Initializer.instance.removeEventListener(ErrorEvent.ERROR, failed);

    }
}
}
