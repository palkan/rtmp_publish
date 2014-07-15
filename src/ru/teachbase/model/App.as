/**
 * User: palkan
 * Date: 5/29/13
 * Time: 12:37 PM
 */
package ru.teachbase.model {
import flash.display.Stage;

import ru.teachbase.managers.PublishManager;
import ru.teachbase.managers.RTMPManager;

import mx.core.FlexGlobals;

import ru.teachbase.manage.Manager;

public class App {
    private static var _view:MainApplication;

    [Bindable]
    public static var params:PublishParams = new PublishParams();

    //------------ constructor ------------//

    //------------ initialize ------------//

    //--------------- ctrl ---------------//


    public static function setView(value:MainApplication):void {
        _view = value;
    }


    public static function get view():MainApplication {
        return _view;
    }

    public static function get rtmp():RTMPManager {
        return (Manager.getManagerInstance(RTMPManager, true) as RTMPManager);
    }

    public static function get publisher():PublishManager {
        return (Manager.getManagerInstance(PublishManager, true) as PublishManager);
    }

    public static function get stage():Stage {
        if (FlexGlobals.topLevelApplication)
            return FlexGlobals.topLevelApplication.stage;

        return null;
    }
}
}
