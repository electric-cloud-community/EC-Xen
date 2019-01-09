my $pluginName = "@PLUGIN_NAME@";

my %Cleanup = (
               label       => "Xen - Cleanup Virtual Machine",
               procedure   => "Cleanup",
               description => "Delete EC resources and optionally destroy the virtual machine(s) in Xen",
               category    => "Resource Management"
              );

my %Clone = (
             label       => "Xen - Clone Virtual Machine",
             procedure   => "Clone",
             description => "Clone the specified VM, making a new VM",
             category    => "Resource Management"
            );

my %CreateResourceFromVM = (
                            label       => "Xen - Create Resource From Virtual Machine",
                            procedure   => "CreateResourceFromVM",
                            description => "Create resource from a virtual machine",
                            category    => "Resource Management"
                           );

my %Destroy = (
               label       => "Xen - Destroy Virtual Machine",
               procedure   => "Destroy",
               description => "Destroy the specified VM",
               category    => "Resource Management"
              );

my %Pause = (
             label       => "Xen - Pause Virtual Machine",
             procedure   => "Pause",
             description => "Pause the specified VM",
             category    => "Resource Management"
            );

my %Provision = (
                 label       => "Xen - Provision Virtual Machine",
                 procedure   => "Provision",
                 description => "Create a new VM instance from an existing template",
                 category    => "Resource Management"
                );

my %Reboot = (
              label       => "Xen - Reboot Virtual Machine",
              procedure   => "Reboot",
              description => "Reboot the specified VM",
              category    => "Resource Management"
             );

my %Resume = (
              label       => "Xen - Resume Virtual Machine",
              procedure   => "Resume",
              description => "Awake the specified VM and resume it",
              category    => "Resource Management"
             );

my %Shutdown = (
                label       => "Xen - Shutdown Virtual Machine",
                procedure   => "Shutdown",
                description => "Shutdown the specified VM",
                category    => "Resource Management"
               );

my %Start = (
             label       => "Xen - Start Virtual Machine",
             procedure   => "Start",
             description => "Start the specified VM",
             category    => "Resource Management"
            );

my %Suspend = (
               label       => "Xen - Suspend Virtual Machine",
               procedure   => "Suspend",
               description => "Suspend the specified VM to disk",
               category    => "Resource Management"
              );

my %Unpause = (
               label       => "Xen - Unpause Virtual Machine",
               procedure   => "Unpause",
               description => "Unpause the specified VM",
               category    => "Resource Management"
              );

##Delete Old style
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Xen - Cleanup");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Xen - Clone");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Xen - CreateResourceFromVM");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Xen - Destroy");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Xen - Pause");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Xen - Provision");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Xen - Reboot");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Xen - Resume");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Xen - Shutdown");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Xen - Start");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Xen - Suspend");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Xen - Unpause");

##Delete step chooser
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Xen - Cleanup Virtual Machine");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Xen - Clone Virtual Machine");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Xen - Create Resource From Virtual Machine");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Xen - Destroy Virtual Machine");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Xen - Pause Virtual Machine");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Xen - Provision Virtual Machine");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Xen - Reboot Virtual Machine");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Xen - Resume Virtual Machine");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Xen - Shutdown Virtual Machine");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Xen - Start Virtual Machine");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Xen - Suspend Virtual Machine");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Xen - Unpause Virtual Machine");

@::createStepPickerSteps = (\%Cleanup, \%Clone, \%CreateResourceFromVM, \%Destroy, \%Pause, \%Provision, \%Reboot, \%Resume, \%Shutdown, \%Start, \%Suspend, \%Unpause);

if ($promoteAction ne '') {
    my @objTypes = ('projects', 'resources', 'workspaces');
    my $query    = $commander->newBatch();
    my @reqs     = map { $query->getAclEntry('user', "project: $pluginName", { systemObjectName => $_ }) } @objTypes;
    push @reqs, $query->getProperty('/server/ec_hooks/promote');
    $query->submit();

    foreach my $type (@objTypes) {
        if ($query->findvalue(shift @reqs, 'code') ne 'NoSuchAclEntry') {
            $batch->deleteAclEntry('user', "project: $pluginName", { systemObjectName => $type });
        }
    }

    if ($promoteAction eq 'promote') {
        foreach my $type (@objTypes) {
            $batch->createAclEntry(
                                   'user',
                                   "project: $pluginName",
                                   {
                                      systemObjectName           => $type,
                                      readPrivilege              => 'allow',
                                      modifyPrivilege            => 'allow',
                                      executePrivilege           => 'allow',
                                      changePermissionsPrivilege => 'allow'
                                   }
                                  );
        }
    }

}

if ($upgradeAction eq 'upgrade') {
    my $query   = $commander->newBatch();
    my $newcfg  = $query->getProperty("/plugins/$pluginName/project/xen_cfgs");
    my $oldcfgs = $query->getProperty("/plugins/$otherPluginName/project/xen_cfgs");
    my $creds   = $query->getCredentials("\$[/plugins/$otherPluginName]");

    local $self->{abortOnError} = 0;
    $query->submit();

    # if new plugin does not already have cfgs
    if ($query->findvalue($newcfg, 'code') eq 'NoSuchProperty') {

        # if old cfg has some cfgs to copy
        if ($query->findvalue($oldcfgs, 'code') ne 'NoSuchProperty') {
            $batch->clone(
                          {
                            path      => "/plugins/$otherPluginName/project/xen_cfgs",
                            cloneName => "/plugins/$pluginName/project/xen_cfgs"
                          }
                         );
        }
    }

    # Copy configuration credentials and attach them to the appropriate steps
    my $nodes = $query->find($creds);
    if ($nodes) {
        my @nodes = $nodes->findnodes('credential/credentialName');
        for (@nodes) {
            my $cred = $_->string_value;

            # Clone the credential
            $batch->clone(
                          {
                            path      => "/plugins/$otherPluginName/project/credentials/$cred",
                            cloneName => "/plugins/$pluginName/project/credentials/$cred"
                          }
                         );

            # Make sure the credential has an ACL entry for the new project principal
            my $xpath = $commander->getAclEntry(
                                                "user",
                                                "project: $pluginName",
                                                {
                                                   projectName    => $otherPluginName,
                                                   credentialName => $cred
                                                }
                                               );
            if ($xpath->findvalue('//code') eq 'NoSuchAclEntry') {
                $batch->deleteAclEntry(
                                       "user",
                                       "project: $otherPluginName",
                                       {
                                          projectName    => $pluginName,
                                          credentialName => $cred
                                       }
                                      );
                $batch->createAclEntry(
                                       "user",
                                       "project: $pluginName",
                                       {
                                          projectName                => $pluginName,
                                          credentialName             => $cred,
                                          readPrivilege              => "allow",
                                          modifyPrivilege            => "allow",
                                          executePrivilege           => "allow",
                                          changePermissionsPrivilege => "allow"
                                       }
                                      );
            }

            # Attach the credential to the appropriate steps
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Provision',
                                        stepName      => 'Provision'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Destroy',
                                        stepName      => 'Destroy'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Start',
                                        stepName      => 'Start'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Clone',
                                        stepName      => 'Clone'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Pause',
                                        stepName      => 'Pause'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Unpause',
                                        stepName      => 'Unpause'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Suspend',
                                        stepName      => 'Suspend'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Resume',
                                        stepName      => 'Resume'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Shutdown',
                                        stepName      => 'Shutdown'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Reboot',
                                        stepName      => 'Reboot'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'Cleanup',
                                        stepName      => 'Cleanup'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'CreateResourceFromVM',
                                        stepName      => 'CreateResourceFromVM'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'CreateConfiguration',
                                        stepName      => 'CreateConfiguration'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'CloudManagerGrow',
                                        stepName      => 'grow'
                                     }
                                    );
            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'CloudManagerShrink',
                                        stepName      => 'shrink'
                                     }
                                    );

            $batch->attachCredential(
                                     "\$[/plugins/$pluginName/project]",
                                     $cred,
                                     {
                                        procedureName => 'CloudManagerSync',
                                        stepName      => 'sync'
                                     }
                                    );

        }
    }
}

