@files = (
    ['//property[propertyName="ui_forms"]/propertySheet/property[propertyName="XenCreateConfigForm"]/value', 'XenCreateConfigForm.xml'],
    ['//property[propertyName="ui_forms"]/propertySheet/property[propertyName="XenEditConfigForm"]/value',   'XenEditConfigForm.xml'],
    ['//property[propertyName="preamble"]/value',                                                            'preamble.pl'],
    ['//property[propertyName="Xen"]/value',                                                                 'Xen.pm'],
    ['//property[propertyName="ec_setup"]/value',                                                            'ec_setup.pl'],

    ['//procedure[procedureName="CreateConfiguration"]/step[stepName="CreateConfiguration"]/command',       'conf/createcfg.pl'],
    ['//procedure[procedureName="CreateConfiguration"]/step[stepName="CreateAndAttachCredential"]/command', 'conf/createAndAttachCredential.pl'],
    ['//procedure[procedureName="DeleteConfiguration"]/step[stepName="DeleteConfiguration"]/command',       'conf/deletecfg.pl'],
    ['//procedure[procedureName="Provision"]/step[stepName="Provision"]/command',                           'xen/provision.pl'],
    ['//procedure[procedureName="Provision"]/step[stepName="SetTimelimit"]/command',                        'setTimelimit.pl'],
    ['//procedure[procedureName="Destroy"]/step[stepName="Destroy"]/command',                               'xen/destroy.pl'],
    ['//procedure[procedureName="Destroy"]/step[stepName="SetTimelimit"]/command',                          'setTimelimit.pl'],
    ['//procedure[procedureName="Start"]/step[stepName="Start"]/command',                                   'xen/start.pl'],
    ['//procedure[procedureName="Start"]/step[stepName="SetTimelimit"]/command',                            'setTimelimit.pl'],
    ['//procedure[procedureName="Clone"]/step[stepName="Clone"]/command',                                   'xen/clone.pl'],
    ['//procedure[procedureName="Clone"]/step[stepName="SetTimelimit"]/command',                            'setTimelimit.pl'],
    ['//procedure[procedureName="Pause"]/step[stepName="Pause"]/command',                                   'xen/pause.pl'],
    ['//procedure[procedureName="Pause"]/step[stepName="SetTimelimit"]/command',                            'setTimelimit.pl'],
    ['//procedure[procedureName="Unpause"]/step[stepName="Unpause"]/command',                               'xen/unpause.pl'],
    ['//procedure[procedureName="Unpause"]/step[stepName="SetTimelimit"]/command',                          'setTimelimit.pl'],
    ['//procedure[procedureName="Suspend"]/step[stepName="Suspend"]/command',                               'xen/suspend.pl'],
    ['//procedure[procedureName="Suspend"]/step[stepName="SetTimelimit"]/command',                          'setTimelimit.pl'],
    ['//procedure[procedureName="Resume"]/step[stepName="Resume"]/command',                                 'xen/resume.pl'],
    ['//procedure[procedureName="Resume"]/step[stepName="SetTimelimit"]/command',                           'setTimelimit.pl'],
    ['//procedure[procedureName="Shutdown"]/step[stepName="Shutdown"]/command',                             'xen/shutdown.pl'],
    ['//procedure[procedureName="Shutdown"]/step[stepName="SetTimelimit"]/command',                         'setTimelimit.pl'],
    ['//procedure[procedureName="Reboot"]/step[stepName="Reboot"]/command',                                 'xen/reboot.pl'],
    ['//procedure[procedureName="Reboot"]/step[stepName="SetTimelimit"]/command',                           'setTimelimit.pl'],
    ['//procedure[procedureName="Cleanup"]/step[stepName="Cleanup"]/command',                               'xen/cleanup.pl'],
    ['//procedure[procedureName="Cleanup"]/step[stepName="SetTimelimit"]/command',                          'setTimelimit.pl'],
    ['//procedure[procedureName="CreateResourceFromVM"]/step[stepName="CreateResourceFromVM"]/command',     'xen/createResourceFromVM.pl'],
    ['//procedure[procedureName="CreateResourceFromVM"]/step[stepName="SetTimelimit"]/command',             'setTimelimit.pl'],
    ['//procedure[procedureName="CloudManagerGrow"]/step[stepName="grow"]/command',                         'xen/step.grow.pl'],
    ['//procedure[procedureName="CloudManagerShrink"]/step[stepName="shrink"]/command',                     'xen/step.shrink.pl'],
    ['//procedure[procedureName="CloudManagerSync"]/step[stepName="sync"]/command',                         'xen/step.sync.pl'],

    #forms
    ['//procedure[procedureName="CreateConfiguration"]/propertySheet/property[propertyName="ec_parameterForm"]/value',  'XenCreateConfigForm.xml'],
    ['//procedure[procedureName="Cleanup"]/propertySheet/property[propertyName="ec_parameterForm"]/value',              'forms/Cleanup.xml'],
    ['//procedure[procedureName="Clone"]/propertySheet/property[propertyName="ec_parameterForm"]/value',                'forms/Clone.xml'],
    ['//procedure[procedureName="CreateResourceFromVM"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'forms/CreateResourceFromVM.xml'],
    ['//procedure[procedureName="DeleteConfiguration"]/propertySheet/property[propertyName="ec_parameterForm"]/value',  'forms/DeleteConfiguration.xml'],
    ['//procedure[procedureName="Destroy"]/propertySheet/property[propertyName="ec_parameterForm"]/value',              'forms/Destroy.xml'],
    ['//procedure[procedureName="Pause"]/propertySheet/property[propertyName="ec_parameterForm"]/value',                'forms/Pause.xml'],
    ['//procedure[procedureName="Provision"]/propertySheet/property[propertyName="ec_parameterForm"]/value',            'forms/Provision.xml'],
    ['//procedure[procedureName="Reboot"]/propertySheet/property[propertyName="ec_parameterForm"]/value',               'forms/Reboot.xml'],
    ['//procedure[procedureName="Resume"]/propertySheet/property[propertyName="ec_parameterForm"]/value',               'forms/Resume.xml'],
    ['//procedure[procedureName="Shutdown"]/propertySheet/property[propertyName="ec_parameterForm"]/value',             'forms/Shutdown.xml'],
    ['//procedure[procedureName="Start"]/propertySheet/property[propertyName="ec_parameterForm"]/value',                'forms/Start.xml'],
    ['//procedure[procedureName="Suspend"]/propertySheet/property[propertyName="ec_parameterForm"]/value',              'forms/Suspend.xml'],
    ['//procedure[procedureName="Unpause"]/propertySheet/property[propertyName="ec_parameterForm"]/value',              'forms/Unpause.xml'],
    ['//procedure[procedureName="CloudManagerGrow"]/propertySheet/property[propertyName="ec_parameterForm"]/value',     'forms/Grow.xml'],
    ['//procedure[procedureName="CloudManagerShrink"]/propertySheet/property[propertyName="ec_parameterForm"]/value',   'forms/Shrink.xml'],
    ['//procedure[procedureName="CloudManagerSync"]/propertySheet/property[propertyName="ec_parameterForm"]/value',     'forms/Sync.xml'],

         );
