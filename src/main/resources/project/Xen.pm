# -----------------------------------------------------------------------------
# Copyright 2005-2011 Electric Cloud Corporation
#
#
# Package
#    Xen.pm
#
# Purpose
#    A perl library that encapsulates the logic to call procedures from Xen API
#
#
# Dependencies
#    Requires Perl with specific modules
#        RPC::XML
#        ElectricCommander.pm
#
# The following special keyword indicates that the "cleanup" script should
# scan this file for formatting errors, even though it doesn't have one of
# the expected extensions.
# CLEANUP: CHECK
#
# Copyright (c) 2005-2010 Electric Cloud, Inc.
# All rights reserved
# -----------------------------------------------------------------------------

package Xen;

# -----------------------------------------------------------------------------
# Includes
# -----------------------------------------------------------------------------
use lib $ENV{COMMANDER_PLUGINS} . '/@PLUGIN_NAME@/agent/lib';

use strict;
use warnings;

use Encode;
use utf8;
use open IO => ':encoding(utf8)';
use Net::Ping;
use ElectricCommander;
use ElectricCommander::PropDB;

use XML::XPath;
use Data::Dumper;
use Time::HiRes;

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
use constant {

    TRUE  => 1,
    FALSE => 0,

    DEFAULT_PINGTIMEOUT   => 300,
    DEFAULT_DEBUG         => 2,
    DEFAULT_LOCATION      => '/myJob/Xen/vms',
    DEFAULT_SLEEP         => 5,
    DEFAULT_NUMBER_OF_VMS => 1,
    WAIT_SLEEP_TIME       => 60,

    DEBUG_LEVEL_0 => 0,
    DEBUG_LEVEL_1 => 1,
    DEBUG_LEVEL_2 => 2,
    DEBUG_LEVEL_5 => 5,

    SUCCESS => 0,
    ERROR   => 1,

    ALIVE     => 1,
    NOT_ALIVE => 0,
};

# ------------------------------------------------------------------------
# Globals
# ------------------------------------------------------------------------

$::gServer      = '';
$::resourceList = '';
$::vmsList      = '';
$::results      = TRUE;
$::vif          = '0';

###############################################################################
# new - Object constructor for LabManager
#
# Arguments:
#   cmdr - ElectricCommander object
#   opts - hash
#
# Returns:
#   none
#
###############################################################################
sub new {
    my $class = shift;
    my $self = {
                 _cmdr => shift,
                 _opts => shift,
               };
    bless $self, $class;
}

###############################################################################
# my_cmdr - Get ElectricCommander instance
#
# Arguments:
#   none
#
# Returns:
#   ElectricCommander instance
#
###############################################################################
sub my_cmdr {
    my ($self) = @_;
    return $self->{_cmdr};
}

###############################################################################
# opts - Get opts hash
#
# Arguments:
#   none
#
# Returns:
#   opts hash
#
###############################################################################
sub opts {
    my ($self) = @_;
    return $self->{_opts};
}

###############################################################################
# check_valid_location - Check if location specified in PropPrefix is valid
#
# Arguments:
#   none
#
# Returns:
#   0 - Success
#   1 - Error
#
###############################################################################
sub check_valid_location {
    my ($self) = @_;
    my $location = '/test-' . $self->opts->{JobStepId};

    # Test set property in location
    my $result = $self->setProp($location, 'Test property');
    if (!defined($result) || $result eq q{}) {
        $self->debug_msg(DEBUG_LEVEL_0, 'Invalid location: ' . $self->opts->{PropPrefix});
        return ERROR;
    }

    # Test get property in location
    $result = $self->getProp($location);
    if (!defined($result) || $result eq q{}) {
        $self->debug_msg(DEBUG_LEVEL_0, 'Invalid location: ' . $self->opts->{PropPrefix});
        return ERROR;
    }

    # Delete property
    $result = $self->deleteProp($location);
    return SUCCESS;
}

###############################################################################
# ecode - Get exit code
#
# Arguments:
#   none
#
# Returns:
#   exit code number
#
###############################################################################
sub ecode {
    my ($self) = @_;
    return $self->opts()->{exitcode};
}

###############################################################################
# myProp - Get PropDB
#
# Arguments:
#   none
#
# Returns:
#   PropDB
#
###############################################################################
sub myProp {
    my ($self) = @_;
    return $self->{_props};
}

###############################################################################
# setProp - Use stored property prefix and PropDB to set a property
#
# Arguments:
#   location - relative location to set the property
#   value    - value of the property
#
# Returns:
#   setResult - result returned by PropDB->setProp
#
###############################################################################
sub setProp {
    my ($self, $location, $value) = @_;
    my $set_result = $self->myProp->setProp($self->opts->{PropPrefix} . $location, $value);
    return $set_result;
}

###############################################################################
# getProp - Use stored property prefix and PropDB to get a property
#
# Arguments:
#   location - relative location to get the property
#
# Returns:
#   getResult - property value
#
###############################################################################
sub getProp {
    my ($self, $location) = @_;
    my $get_result = $self->myProp->getProp($self->opts->{PropPrefix} . $location);
    return $get_result;
}

###############################################################################
# deleteProp - Use stored property prefix and PropDB to delete a property
#
# Arguments:
#   location - relative location of the property to delete
#
# Returns:
#   delResult - result returned by PropDB->deleteProp
#
###############################################################################
sub deleteProp {
    my ($self, $location) = @_;
    my $del_result = $self->myProp->deleteProp($self->opts->{PropPrefix} . $location);
    return $del_result;
}

###############################################################################
# trim -R emove blank spaces before and after string
#
# Arguments:
#   string
#
# Returns:
#   trimmed string
#
###############################################################################
sub trim {
    my ($self, $string) = @_;
    $string =~ s/^\s+//xsm;
    $string =~ s/\s+$//xsm;
    return $string;
}

###############################################################################
# debug_msg - Print a debug message
#
# Arguments:
#   errorlevel - number compared to $self->opts->{debug}
#   msg        - string message
#
# Returns:
#   none
#
###############################################################################
sub debug_msg {
    my ($self, $errlev, $msg) = @_;

    if ($self->opts->{debug} >= $errlev) {
        binmode STDOUT, ':encoding(utf8)';
        binmode STDIN,  ':encoding(utf8)';
        binmode STDERR, ':encoding(utf8)';

        print {*STDOUT} "$msg\n";
    }
    return;
}

###############################################################################
# initialize - Initializes object options
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub initialize {
    my ($self) = @_;

    $self->{_props} = ElectricCommander::PropDB->new($self->my_cmdr(), q{});

    if (!defined($self->opts->{debug})) {
        $self->opts->{debug} = DEFAULT_DEBUG;
    }
    $self->opts->{exitcode} = SUCCESS;

    if (!defined($self->opts->{PingTimeout})) {
        $self->opts->{PingTimeout} = DEFAULT_PINGTIMEOUT;    # timeout to wait for agent ping in secs
    }

    if ($self->opts->{debug} >= DEBUG_LEVEL_5) {
        foreach my $o (sort keys %{ $self->opts }) {
            if ($o eq "xen_pass") { next; }
            $self->debug_msg(DEBUG_LEVEL_5, " option {$o}=" . $self->opts->{$o});
        }
    }

    require RPC::XML;
    require RPC::XML::Client;

    $RPC::XML::ENCODING              = "UTF-8";
    $RPC::XML::FORCE_STRING_ENCODING = TRUE;

    return;
}

###############################################################################
# initializePropPrefix - Initialize PropPrefix value and check valid location
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub initialize_prop_prefix {
    my ($self) = @_;

    # setup the property sheet where information will be exchanged
    if (!defined($self->opts->{ec_properties_location}) || $self->opts->{ec_properties_location} eq q{}) {
        $::results = FALSE;
        if ($self->opts->{JobStepId} ne '1') {
            $self->opts->{ec_properties_location} = DEFAULT_LOCATION;    # default location to save properties
        }
        else {
            $self->debug_msg(DEBUG_LEVEL_0, 'Must specify property sheet location when not running in job');
            $self->opts->{exitcode} = ERROR;
            return;
        }
    }
    $self->opts->{PropPrefix} = $self->opts->{ec_properties_location};
    if (defined($self->opts->{tag}) && $self->opts->{tag} ne q{}) {
        $self->opts->{PropPrefix} .= q{/} . $self->opts->{tag};
    }

    # test that the location is valid
    if ($self->check_valid_location) {
        $self->opts->{exitcode} = ERROR;
        return;
    }

}

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

###############################################################################
# checkserver - Checks if the Xen server is reachable
#
# Arguments:
#   server name
#
# Returns:
#   true if the server is reachable, 0 if is not.
#
###############################################################################
sub checkserver {

    my ($self, $server) = @_;

    $server =~ s/(.*:\/\/)?(\w{3}\.)?//ixms;

    my $ping = Net::Ping->new();
    $ping->hires();
    my ($ret, $duration, $ip) = $ping->ping($server, 5.5);
    $ping->close();

    if (defined $ret) {
        if ($ip =~ m/\d*\.\d*\.\d*\.\d*/ixms) {
            return 1;
        }
    }
    return 0;
}

###############################################################################
# login - Establish a connection with Xen
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub login {
    my ($self) = @_;

    my $session;
    $::gServer = $self->opts->{xen_server};

    # Connect only if hostname is set
    if (defined($self->opts->{xen_server}) && $self->opts->{xen_server} ne q{}) {

        # Check server status

        $self->debug_msg(DEBUG_LEVEL_5, "- Ping to server: " . $self->opts->{xen_server});
        if (!$self->checkserver($self->opts->{xen_server})) {

            $self->debug_msg(DEBUG_LEVEL_0, "[ERROR] " . $self->opts->{xen_server} . " is not reachable.");
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $self->debug_msg(DEBUG_LEVEL_5, "- Ping successfull!!");

        # Establish the XEN API connection
        my $client = RPC::XML::Client->new("http://$::gServer");
        my $response = $client->simple_request('session.login_with_password', $self->opts->{xen_user}, $self->opts->{xen_pass});

        if (!defined($response)) {
            $self->debug_msg(DEBUG_LEVEL_0, "[ERROR] Connection failure: " . $RPC::XML::ERROR);
            $self->opts->{exitcode} = ERROR;
            return;
        }
        $session = $response->{'Value'};

        return ($session, $client);
    }
}

###############################################################################
# logout - Terminate a connection with Xen
#
# Arguments:
#   session  - Xen session_id
#
# Returns:
#   none
#
###############################################################################
sub logout {
    my ($self, $session, $xen) = @_;

    # Terminate the XEN API connection
    my $req = $xen->simple_request('session.logout', $session);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, "[ERROR] Logout failure: $req->{'ErrorDescription'}[0]");
        $self->opts->{exitcode} = ERROR;
        return;
    }

    $self->debug_msg(DEBUG_LEVEL_0, 'Connection successfully terminated.');
    return;
}

###############################################################################
# getTemplate - Get VM template reference
#
# Arguments:
#   session    - Xen session_id
#   xen        - RPC::XML::Client instance
#
# Returns:
#   VM ref - string
#
###############################################################################
sub getTemplate {
    my ($self, $session, $xen) = @_;

    my $template_ref = q{};

    $self->debug_msg(DEBUG_LEVEL_5, '- Getting VM Template reference...');

    #-----------------------------------------------------------------------------
    # Get a list of all the VMs known to the system
    #-----------------------------------------------------------------------------
    my $vms_refs;

    # Get the reference for all the VMs known to the system.
    my $req = $xen->simple_request('VM.get_all_records', $session);
    if (!defined($req)) {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get VMs: ' . $RPC::XML::ERROR);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    $vms_refs = $req->{'Value'};

    my @keys = keys %{$vms_refs};
    my $size = @keys;

    $self->debug_msg(DEBUG_LEVEL_1, 'Server has ' . $size . ' VM objects (this includes templates).');

    #-----------------------------------------------------------------------------
    # Get VM template
    #-----------------------------------------------------------------------------
    foreach my $vm_ref (keys %{$vms_refs}) {

        # Get VM record
        $req = $xen->simple_request('VM.get_record', $session, $vm_ref);
        if (!defined($req)) {
            $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get VM record: ' . $RPC::XML::ERROR);
            $self->opts->{exitcode} = ERROR;
            return;
        }
        my $vmrecord = $req->{'Value'};

        my $vmname         = $vmrecord->{name_label};
        my $vm_is_template = $vmrecord->{is_a_template};

        if (($vmname eq $self->opts->{xen_template}) && ($vm_is_template)) {
            $self->debug_msg(DEBUG_LEVEL_0, 'Found template with name_label = ' . $self->opts->{xen_template});
            $template_ref = $vm_ref;

            $self->debug_msg(DEBUG_LEVEL_5, '- Template reference: ' . $vm_ref);

            last;
        }

    }

    if ($template_ref eq q{}) {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Could not find template: ' . $self->opts->{xen_template});
        $self->opts->{exitcode} = ERROR;
        return;
    }

    return $template_ref;
}

###############################################################################
# getNetwork - Get Network reference
#
# Arguments:
#   session    - Xen session_id
#   xen        - RPC::XML::Client instance
#
# Returns:
#   Network ref - string
#
###############################################################################
sub getNetwork {
    my ($self, $session, $xen) = @_;

    my $network_ref;

    $self->debug_msg(DEBUG_LEVEL_5, '- Getting VM Network reference...');

    #-----------------------------------------------------------------------------
    # Get a list of all the PIFs known to the system
    #-----------------------------------------------------------------------------
    my $pifs_refs;

    # Get the reference for all the PIFs known to the system.
    my $req = $xen->simple_request('PIF.get_all_records', $session);
    if (!defined($req)) {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get PIFs: ' . $RPC::XML::ERROR);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    $pifs_refs = $req->{'Value'};

    #-----------------------------------------------------------------------------
    # Get Network
    #-----------------------------------------------------------------------------
    foreach my $pif_ref (keys %{$pifs_refs}) {

        # Get network reference
        $req = $xen->simple_request('PIF.get_network', $session, $pif_ref);
        if (!defined($req)) {
            $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get network reference: ' . $RPC::XML::ERROR);
            $self->opts->{exitcode} = ERROR;
            return;
        }
        my $net_ref = $req->{'Value'};

        # Get network name

        $req = $xen->simple_request('network.get_name_label', $session, $net_ref);
        if (!defined($req)) {
            $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get network name: ' . $RPC::XML::ERROR);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        my $netname = $req->{'Value'};

        if ($netname eq $self->opts->{xen_network}) {
            $self->debug_msg(DEBUG_LEVEL_0, 'Found network "' . $self->opts->{xen_network} . '"');
            $network_ref = $net_ref;

            $self->debug_msg(DEBUG_LEVEL_5, '- Network reference: ' . $network_ref);

            last;
        }

    }

    if ($network_ref eq q{}) {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Could not find network: ' . $self->opts->{xen_network});
        $self->opts->{exitcode} = ERROR;
        return;
    }

    return $network_ref;
}

###############################################################################
# checkStatus - Check the current status of a VM
#
# Arguments:
#   session    - Xen session_id
#   xen        - RPC::XML::Client instance
#   vm_ref     - Xen VM reference
#
# Returns:
#   VM state - string
#
###############################################################################
sub checkStatus {
    my ($self, $session, $xen, $vm_ref) = @_;
    my $vmstate;
    # Get the status of the VM
    my $req = $xen->simple_request('VM.get_power_state', $session, $vm_ref);

    if ($req->{'Status'} eq 'Failure') {
     if($req->{'ErrorDescription'}[0] ne 'HANDLE_INVALID')
    {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get power state: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;}
        $self->opts->{status_error} = 'HANDLE_INVALID';
        return 'Halted';
    }

    $vmstate = $req->{'Value'};

    return $vmstate;

}

###############################################################################
# getDeployedResourceListFromProperty - Read the list of configurations deployed for a tag
#
# Arguments:
#   none
#
# Returns:
#   array of resources on success
#   empty array on failure
#
###############################################################################

sub getDeployedVMListFromProperty {
    my ($self) = @_;

    my $propPrefix = $self->opts->{PropPrefix};
    $self->debug_msg(DEBUG_LEVEL_2, 'Finding VMs recorded in path ' . $propPrefix);
    my $vmList = $self->getProp("/vmsList") || "";

    my @vmList = split(/;/, $vmList);

    return @vmList;
}

sub getDeployedResourceListFromProperty {
    my ($self) = @_;

    my $propPrefix = $self->opts->{PropPrefix};

    #$self->debug_msg(DEBUG_LEVEL_2, 'Finding Resources recorded in path ' . $propPrefix);
    my $resList = $self->getProp("/resourceList") || "";

    my @resList = split(/;/, $resList);

    return @resList;
}

###############################################################################
# pingResource - Use commander to ping a resource
#
# Arguments:
#   resource - string
#
# Returns:
#   1 if alive, 0 otherwise
#
###############################################################################
sub pingResource {
    my ($self, $resource) = @_;

    my $alive  = NOT_ALIVE;
    my $result = $self->my_cmdr()->pingResource($resource);
    if (!$result) { return NOT_ALIVE; }
    $alive = $result->findvalue('//alive');
    if ($alive eq ALIVE) { return ALIVE; }
    return NOT_ALIVE;
}

# -----------------------------------------------------------------------------
# Main procedures
# -----------------------------------------------------------------------------

###############################################################################
# provision - Call provision_vm the number of times specified  by 'xen_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub provision {
    my ($self) = @_;

    # Initialize
    $self->initialize();
    if ($self->opts->{exitcode}) { return; }
    $self->initialize_prop_prefix;
    if ($self->opts->{exitcode}) { return; }

    #-----------------------------------------------------------------------------
    # Login and get Session
    #-----------------------------------------------------------------------------
    my ($session, $xen) = $self->login();
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Provision
    #-----------------------------------------------------------------------------
    if ($self->opts->{xen_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {
        $self->provision_vm($session, $xen);
    }
    else {
        my $vm_prefix = $self->opts->{xen_vmname};
        my $vm_number;
        for (1 .. $self->opts->{xen_number_of_vms}) {
            $vm_number = $_;
            $self->opts->{xen_vmname} = $vm_prefix . '_' . $vm_number;
            $self->provision_vm($session, $xen);
        }
    }

    $self->setProp('/resourceList', $::resourceList);
    $self->setProp('/vmsList',      $::vmsList);

    #-----------------------------------------------------------------------------
    # Logout
    #-----------------------------------------------------------------------------
    $self->logout($session, $xen);
    if ($self->ecode) { return; }

    return;
}

###############################################################################
# provision - Instantiate and start a VM
#
# Arguments:
#   -
#
# Returns:
#   -
#
###############################################################################
sub provision_vm {
    my ($self, $session, $xen) = @_;

    $self->debug_msg(DEBUG_LEVEL_1, '----------------------------------------------------------------------------------------------------');

    my $req;
    my $mtu      = 1500;
    my $vm_check = "";
    my $net_name = "";
    my $vif_ref;

    $self->opts->{exitcode} = SUCCESS;

    #-----------------------------------------------------------------------------
    # Get VM template
    #-----------------------------------------------------------------------------
    my $vmtemplate = $self->getTemplate($session, $xen);
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Check VM name not in use
    #-----------------------------------------------------------------------------
    $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to check VM name to use: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    if ($req->{'Value'}[0]) {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to instantiate template: VM name: \'' . $self->opts->{xen_vmname} . '\' already in use');
        $self->opts->{exitcode} = ERROR;
        return;
    }

    #-----------------------------------------------------------------------------
    # Instatiate template
    #-----------------------------------------------------------------------------
    $self->debug_msg(DEBUG_LEVEL_0, 'Instantiating the template \'' . $self->opts->{xen_template} . '\' to create VM "' . $self->opts->{xen_vmname} . '"...');

    ##-----------------------------
    ## Get VM status
    ##-----------------------------
    my $vmstate = $self->checkStatus($session, $xen, $vmtemplate);
    if ($self->ecode) { return; }

    if ($vmstate ne 'Halted') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to instantiate VM Template: This function can only be called when the VM is in the Halted State.');
        $self->opts->{exitcode} = ERROR;
        return;
    }

    ##-----------------------------
    ## Clone VM template
    ##-----------------------------
    $req = $xen->simple_request('VM.clone', $session, $vmtemplate, $self->opts->{xen_vmname});
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to instantiate VM Template: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    my $new_vm_ref = $req->{'Value'};
    sleep WAIT_SLEEP_TIME;
    $self->debug_msg(DEBUG_LEVEL_0, 'New VM created with name: ' . $self->opts->{xen_vmname});
    $self->debug_msg(DEBUG_LEVEL_5, '- VM reference: ' . $new_vm_ref);

    if ("$::vmsList" ne "") { $::vmsList .= ";"; }
    $::vmsList .= $self->opts->{xen_vmname};

    ##-----------------------------
    ## Get Network
    ##-----------------------------
    my $vmnetwork = $self->getNetwork($session, $xen);
    if ($self->ecode) { return; }

    ##-----------------------------
    ## Check existing VIF is connected to $vmnetwork
    ##-----------------------------

    $req = $xen->simple_request('VM.get_VIFs', $session, $new_vm_ref);

    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get VIFs: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    my @vifs_ref = $req->{'Value'}[0];

    foreach my $vif (@vifs_ref) {
        print $vif. "\n";

        $req = $xen->simple_request('VIF.get_network', $session, $vif);

        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get Network reference from VIF: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        my $net_ref = $req->{'Value'};

        $req = $xen->simple_request('network.get_name_label', $session, $net_ref);

        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get Network name from VIF: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $net_name = $req->{'Value'};

        if ($net_name eq $self->opts->{xen_network}) {
            $vif_ref = $vif;

            last;
        }

    }

    if ($net_name eq "") {

        ##-----------------------------
        ## Create VIF for new VM
        ##-----------------------------
        $self->debug_msg(DEBUG_LEVEL_5, '- Creating VIF for VM \'' . $self->opts->{xen_vmname} . '\'...');

        my @vif_record = {
                           'MTU'                  => $mtu,
                           'device'               => 1,
                           'network'              => $vmnetwork,
                           'VM'                   => $new_vm_ref,
                           'qos_algorithm_type'   => q{},
                           'MAC'                  => q{},
                           'qos_algorithm_params' => {},
                           'other_config'         => {},
                           'runtime_properties'   => {}
                         };

        $req = $xen->simple_request('VIF.create', $session, @vif_record);

        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to create VIF: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $vif_ref = $req->{'Value'};
        $::vif   = '1';

    }

    $self->debug_msg(DEBUG_LEVEL_5, '- VIF reference: ' . $vif_ref);
    sleep WAIT_SLEEP_TIME;

    ##-----------------------------
    ## Adding 'noniteractive' to the kernel commandline
    ##-----------------------------
    $req = $xen->simple_request('VM.set_PV_args', $session, $new_vm_ref, 'noninteractive');

    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to add noninteractive to kernel command-line arguments: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    ##-----------------------------
    ## Set is_a_template to false
    ##-----------------------------
    $req = $xen->simple_request('VM.set_is_a_template', $session, $new_vm_ref, RPC::XML::boolean->new(0));
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying set is_template to false from VM: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    $self->debug_msg(DEBUG_LEVEL_5, '- VM reference: ' . $new_vm_ref);
    sleep WAIT_SLEEP_TIME;

    #-----------------------------------------------------------------------------
    # Start new VM
    #-----------------------------------------------------------------------------
    $self->debug_msg(DEBUG_LEVEL_0, 'Starting VM \'' . $self->opts->{xen_vmname} . '\'...');
    $self->start_vm($session, $xen, $new_vm_ref);
    if ($self->ecode) { return; }

    sleep WAIT_SLEEP_TIME;

    #-----------------------------------------------------------------------------
    # Store VM information on properties and optionally create resources
    #-----------------------------------------------------------------------------
    $self->storeProperties($session, $xen, $new_vm_ref, $vif_ref);
    if ($self->ecode) { return; }

    $self->debug_msg(DEBUG_LEVEL_0, '*** Successfully provisioned virtual machine "' . $self->opts->{xen_vmname} . '" ***');

    return;
}

###############################################################################
# clone - Call clone_vm the number of times specified  by 'xen_number_of_clones'
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub clone {
    my ($self) = @_;

    # Initialize
    $self->initialize();
    if ($self->opts->{exitcode}) { return; }
    $self->initialize_prop_prefix;
    if ($self->opts->{exitcode}) { return; }

    #-----------------------------------------------------------------------------
    # Login and get Session
    #-----------------------------------------------------------------------------
    my ($session, $xen) = $self->login();
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Clone
    #-----------------------------------------------------------------------------
    my $req;
    my $vm_ref;

    if ($self->opts->{xen_number_of_clones} == DEFAULT_NUMBER_OF_VMS) {
        $self->clone_vm($session, $xen);
    }
    else {
        my $vm_prefix = $self->opts->{xen_vmname};
        my $vm_number;
        for (1 .. $self->opts->{xen_number_of_clones}) {
            $vm_number = $_;
            $self->opts->{xen_vmname} = $vm_prefix . "_$vm_number";
            $self->clone_vm($session, $xen);
        }
    }

    #-----------------------------------------------------------------------------
    # Logout
    #-----------------------------------------------------------------------------
    $self->logout($session, $xen);
    if ($self->ecode) { return; }

    return;
}

###############################################################################
# clone_vm - Create a copy of a VM
#
# Arguments:
#   -
#
# Returns:
#   -
#
###############################################################################
sub clone_vm {
    my ($self, $session, $xen) = @_;

    $self->debug_msg(DEBUG_LEVEL_1, '----------------------------------------------------------------------------------------------------');

    my $req;
    my $vm_check = "";

    #-----------------------------------------------------------------------------
    # Check VM name not in use
    #-----------------------------------------------------------------------------
    $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to check VM name to use: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    $vm_check = $req->{'Value'}[0];

    if ($vm_check ne "") {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to clone vm: New VM name: \'' . $self->opts->{xen_vmname} . '\' already in use');
        $self->opts->{exitcode} = ERROR;
        return;
    }

    #-----------------------------------------------------------------------------
    # Get VM to clone
    #-----------------------------------------------------------------------------
    $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_original_vmname});
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM reference to clone: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    my $vm_ref = $req->{'Value'}[0];

    #-----------------------------------------------------------------------------
    # Get VM status
    #-----------------------------------------------------------------------------
    my $vmstate = $self->checkStatus($session, $xen, $vm_ref);
    if ($self->ecode) { return; }

    if ($vmstate ne 'Halted') {

        #-----------------------------------------------------------------------------
        # ShutDown VM
        #-----------------------------------------------------------------------------
        $self->opts->{xen_hard_shutdown} = '0';
        $self->shutdown_vm($session, $xen, $vm_ref);
        if ($self->ecode) { return; }

    }

    #-----------------------------------------------------------------------------
    # Clone VM
    #-----------------------------------------------------------------------------
    $self->debug_msg(DEBUG_LEVEL_1, 'Cloning VM \'' . $self->opts->{xen_original_vmname} . '\'...');
    $req = $xen->simple_request('VM.clone', $session, $vm_ref, $self->opts->{xen_vmname});
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to clone VM: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    my $new_vm_ref = $req->{'Value'};
    sleep WAIT_SLEEP_TIME;
    $self->debug_msg(DEBUG_LEVEL_0, 'New VM created with name: ' . $self->opts->{xen_vmname});

    #-----------------------------------------------------------------------------
    # Start both VMs
    #-----------------------------------------------------------------------------
    $self->debug_msg(DEBUG_LEVEL_1, 'Starting VM \'' . $self->opts->{xen_vmname} . '\'...');
    $self->start_vm($session, $xen, $new_vm_ref);
    if ($self->ecode) { return; }

    sleep WAIT_SLEEP_TIME;
    sleep WAIT_SLEEP_TIME;

    $self->debug_msg(DEBUG_LEVEL_1, 'Starting VM \'' . $self->opts->{xen_original_vmname} . '\'...');
    $self->start_vm($session, $xen, $vm_ref);
    if ($self->ecode) { return; }

    sleep WAIT_SLEEP_TIME;
    sleep WAIT_SLEEP_TIME;

    #-----------------------------------------------------------------------------
    # Get VM record
    #-----------------------------------------------------------------------------
    $req = $xen->simple_request('VM.get_record', $session, $new_vm_ref);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM record: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    my $vm_vif = $req->{'Value'}{'VIFs'}[0];

    #-----------------------------------------------------------------------------
    # Store VM information on properties and optionally create resources
    #-----------------------------------------------------------------------------
    $self->storeProperties($session, $xen, $new_vm_ref, $vm_vif);
    if ($self->ecode) { return; }

    $self->debug_msg(DEBUG_LEVEL_0, 'Successfully cloned virtual machine ' . $self->opts->{xen_vmname});
    return;
}

###############################################################################
# destroy - Call destroy_vm the number of times specified  by 'xen_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub destroy {
    my ($self) = @_;

    # Initialize
    $self->initialize();
    if ($self->opts->{exitcode}) { return; }
    $self->initialize_prop_prefix;
    if ($self->opts->{exitcode}) { return; }

    #-----------------------------------------------------------------------------
    # Login and get Session
    #-----------------------------------------------------------------------------
    my ($session, $xen) = $self->login();
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Destroy
    #-----------------------------------------------------------------------------
    my $req;
    my $vm_ref;
    $self->debug_msg(DEBUG_LEVEL_1, '----------------------------------------------------------------------------------------------------');

    if ($self->opts->{xen_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {

        #-----------------------------------------------------------------------------
        # Get VM ref
        #-----------------------------------------------------------------------------
        $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $vm_ref = $req->{'Value'}[0];

        $self->debug_msg(DEBUG_LEVEL_0, "Destroying VM '" . $self->opts->{xen_vmname} . "'...");
        $self->destroy_vm($session, $xen, $vm_ref);
    }
    else {
        my $vm_prefix = $self->opts->{xen_vmname};
        my $vm_number;
        for (1 .. $self->opts->{xen_number_of_vms}) {
            $vm_number = $_;
            $self->opts->{xen_vmname} = $vm_prefix . '_' . $vm_number;

            #-----------------------------------------------------------------------------
            # Get VM ref
            #-----------------------------------------------------------------------------
            $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

            $vm_ref = $req->{'Value'}[0];
            $self->debug_msg(DEBUG_LEVEL_0, "Destroying VM '" . $self->opts->{xen_vmname} . "'...");
            $self->destroy_vm($session, $xen, $vm_ref);
        }
    }

    #-----------------------------------------------------------------------------
    # Logout
    #-----------------------------------------------------------------------------
    $self->logout($session, $xen);
    if ($self->ecode) { return; }

    return;
}

###############################################################################
# destroy_vm - Destroy a virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub destroy_vm {
    my ($self, $session, $xen, $vm_ref) = @_;

    #-----------------------------------------------------------------------------
    # Get VM status
    #-----------------------------------------------------------------------------
    my $vmstate = $self->checkStatus($session, $xen, $vm_ref);
    if ($self->ecode) { return; }

    if ($vmstate ne 'Halted') {

        #-----------------------------------------------------------------------------
        # ShutDown VM
        #-----------------------------------------------------------------------------
        $self->opts->{xen_hard_shutdown} = '1';
        $self->shutdown_vm($session, $xen, $vm_ref);
        if ($self->ecode) { return; }

    }

    if(defined($self->opts->{status_error}) && $self->opts->{status_error} eq 'HANDLE_INVALID')
    {
        $self->debug_msg(DEBUG_LEVEL_0, 'VM was already destroyed.');
        return;
    }
    
    #-----------------------------------------------------------------------------
    # Get Storage reference
    #-----------------------------------------------------------------------------
    my $req = $xen->simple_request('VM.get_VBDs', $session, $vm_ref);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM\'s VBDs: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    my $vbds = $req->{'Value'};

    foreach my $vbd_ref (@$vbds) {

        $req = $xen->simple_request('VBD.get_record', $session, $vbd_ref);
        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VBD record: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        my $vbd_record = $req->{'Value'};
        my $vdi_ref    = $vbd_record->{'VDI'};
        if ($vbd_record->{'type'} eq 'Disk') {

            $req = $xen->simple_request('VDI.destroy', $session, $vdi_ref);
            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to destroy VDI: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

        }
    }

    #-----------------------------------------------------------------------------
    # Destroy the VM
    #-----------------------------------------------------------------------------
    $req = $xen->simple_request('VM.destroy', $session, $vm_ref);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to destroy VM: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    $self->debug_msg(DEBUG_LEVEL_0, 'VM successfully destroyed.');
    return;
}

###############################################################################
# start - Call start_vm the number of times specified  by 'xen_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub start {
    my ($self) = @_;

    # Initialize
    $self->initialize();
    if ($self->opts->{exitcode}) { return; }
    $self->initialize_prop_prefix;
    if ($self->opts->{exitcode}) { return; }

    #-----------------------------------------------------------------------------
    # Login and get Session
    #-----------------------------------------------------------------------------
    my ($session, $xen) = $self->login();
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Start
    #-----------------------------------------------------------------------------
    my $req;
    my $vm_ref;
    $self->debug_msg(DEBUG_LEVEL_1, '----------------------------------------------------------------------------------------------------');
    if ($self->opts->{xen_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {

        #-----------------------------------------------------------------------------
        # Get VM ref
        #-----------------------------------------------------------------------------
        $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $vm_ref = $req->{'Value'}[0];
        $self->debug_msg(DEBUG_LEVEL_0, "Starting VM '" . $self->opts->{xen_vmname} . "'...");
        $self->start_vm($session, $xen, $vm_ref);
    }
    else {
        my $vm_prefix = $self->opts->{xen_vmname};
        my $vm_number;
        for (1 .. $self->opts->{xen_number_of_vms}) {
            $vm_number = $_;
            $self->opts->{xen_vmname} = $vm_prefix . '_' . $vm_number;

            #-----------------------------------------------------------------------------
            # Get VM ref
            #-----------------------------------------------------------------------------
            $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

            $vm_ref = $req->{'Value'}[0];
            $self->debug_msg(DEBUG_LEVEL_0, "Starting VM '" . $self->opts->{xen_vmname} . "'...");
            $self->start_vm($session, $xen, $vm_ref);
        }
    }

    #-----------------------------------------------------------------------------
    # Logout
    #-----------------------------------------------------------------------------
    $self->logout($session, $xen);
    if ($self->ecode) { return; }

    return;
}

###############################################################################
# start_vm - Start a virtual machine
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub start_vm {
    my ($self, $session, $xen, $vm_ref) = @_;

    # Start the VM

    my $req = $xen->simple_request('VM.start', $session, $vm_ref, RPC::XML::boolean->new(0), RPC::XML::boolean->new(0));
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to start VM: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    $self->debug_msg(DEBUG_LEVEL_0, 'VM successfully started.');
    return;
}

###############################################################################
# pause - Call pause_vm the number of times specified  by ' xen_number_of_vms '
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub pause {
    my ($self) = @_;

    # Initialize
    $self->initialize();
    if ($self->opts->{exitcode}) { return; }
    $self->initialize_prop_prefix;
    if ($self->opts->{exitcode}) { return; }

    #-----------------------------------------------------------------------------
    # Login and get Session
    #-----------------------------------------------------------------------------
    my ($session, $xen) = $self->login();
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Pause
    #-----------------------------------------------------------------------------
    my $req;
    my $vm_ref;
    $self->debug_msg(DEBUG_LEVEL_1, '----------------------------------------------------------------------------------------------------');
    if ($self->opts->{xen_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {

        #-----------------------------------------------------------------------------
        # Get VM ref
        #-----------------------------------------------------------------------------
        $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $vm_ref = $req->{'Value'}[0];
        $self->debug_msg(DEBUG_LEVEL_0, "Pausing VM '" . $self->opts->{xen_vmname} . "'...");
        $self->pause_vm($session, $xen, $vm_ref);
    }
    else {
        my $vm_prefix = $self->opts->{xen_vmname};
        my $vm_number;
        for (1 .. $self->opts->{xen_number_of_vms}) {
            $vm_number = $_;
            $self->opts->{xen_vmname} = $vm_prefix . '_' . $vm_number;

            #-----------------------------------------------------------------------------
            # Get VM ref
            #-----------------------------------------------------------------------------
            $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

            $vm_ref = $req->{'Value'}[0];
            $self->debug_msg(DEBUG_LEVEL_0, "Pausing VM '" . $self->opts->{xen_vmname} . "'...");
            $self->pause_vm($session, $xen, $vm_ref);
        }
    }

    #-----------------------------------------------------------------------------
    # Logout
    #-----------------------------------------------------------------------------
    $self->logout($session, $xen);
    if ($self->ecode) { return; }

    return;
}

###############################################################################
# pause_vm - Pause the specified VM.
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub pause_vm {
    my ($self, $session, $xen, $vm_ref) = @_;

    #-----------------------------------------------------------------------------
    # Get VM status
    #-----------------------------------------------------------------------------
    my $vmstate = $self->checkStatus($session, $xen, $vm_ref);
    if ($self->ecode) { return; }

    if ($vmstate ne 'Running') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to pause VM: This can only be called when the specified VM is in the Running state.');
        $self->debug_msg(DEBUG_LEVEL_0, "VM state: " . $vmstate);
        $self->opts->{exitcode} = ERROR;
        return;

    }

    #-----------------------------------------------------------------------------
    # Pause the VM
    #-----------------------------------------------------------------------------
    my $req = $xen->simple_request('VM.pause', $session, $vm_ref);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to pause VM: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    $self->debug_msg(DEBUG_LEVEL_0, 'VM successfully paused.');
    return;
}

###############################################################################
# unpause - Call unpause_vm the number of times specified  by 'xen_number_of_vms'
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub unpause {
    my ($self) = @_;

    # Initialize
    $self->initialize();
    if ($self->opts->{exitcode}) { return; }
    $self->initialize_prop_prefix;
    if ($self->opts->{exitcode}) { return; }

    #-----------------------------------------------------------------------------
    # Login and get Session
    #-----------------------------------------------------------------------------
    my ($session, $xen) = $self->login();
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Unpause
    #-----------------------------------------------------------------------------
    my $req;
    my $vm_ref;
    $self->debug_msg(DEBUG_LEVEL_1, '----------------------------------------------------------------------------------------------------');
    if ($self->opts->{xen_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {

        #-----------------------------------------------------------------------------
        # Get VM ref
        #-----------------------------------------------------------------------------
        $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $vm_ref = $req->{'Value'}[0];
        $self->debug_msg(DEBUG_LEVEL_0, "Unpausing VM '" . $self->opts->{xen_vmname} . "'...");
        $self->unpause_vm($session, $xen, $vm_ref);
    }
    else {
        my $vm_prefix = $self->opts->{xen_vmname};
        my $vm_number;
        for (1 .. $self->opts->{xen_number_of_vms}) {
            $vm_number = $_;
            $self->opts->{xen_vmname} = $vm_prefix . '_' . $vm_number;

            #-----------------------------------------------------------------------------
            # Get VM ref
            #-----------------------------------------------------------------------------
            $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

            $vm_ref = $req->{'Value'}[0];
            $self->debug_msg(DEBUG_LEVEL_0, "Unpausing VM '" . $self->opts->{xen_vmname} . "'...");
            $self->unpause_vm($session, $xen, $vm_ref);
        }
    }

    #-----------------------------------------------------------------------------
    # Logout
    #-----------------------------------------------------------------------------
    $self->logout($session, $xen);
    if ($self->ecode) { return; }

    return;
}

###############################################################################
# unpause_vm - Resume the specified VM.
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub unpause_vm {
    my ($self, $session, $xen, $vm_ref) = @_;

    #-----------------------------------------------------------------------------
    # Get VM status
    #-----------------------------------------------------------------------------
    my $vmstate = $self->checkStatus($session, $xen, $vm_ref);
    if ($self->ecode) { return; }

    if ($vmstate ne 'Paused') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to unpause VM: This can only be called when the specified VM is in the Paused state.');
        $self->debug_msg(DEBUG_LEVEL_0, "VM state: " . $vmstate);
        $self->opts->{exitcode} = ERROR;
        return;

    }

    #-----------------------------------------------------------------------------
    # Unpause the VM
    #-----------------------------------------------------------------------------
    my $req = $xen->simple_request('VM.unpause', $session, $vm_ref);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to unpause VM: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    $self->debug_msg(DEBUG_LEVEL_0, 'VM successfully unpaused.');
    return;
}

###############################################################################
# suspend - Call suspend_vm the number of times specified  by ' xen_number_of_vms '
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub suspend {
    my ($self) = @_;

    # Initialize
    $self->initialize();
    if ($self->opts->{exitcode}) { return; }
    $self->initialize_prop_prefix;
    if ($self->opts->{exitcode}) { return; }

    #-----------------------------------------------------------------------------
    # Login and get Session
    #-----------------------------------------------------------------------------
    my ($session, $xen) = $self->login();
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Suspend
    #-----------------------------------------------------------------------------
    my $req;
    my $vm_ref;
    $self->debug_msg(DEBUG_LEVEL_1, '----------------------------------------------------------------------------------------------------');
    if ($self->opts->{xen_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {

        #-----------------------------------------------------------------------------
        # Get VM ref
        #-----------------------------------------------------------------------------
        $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $vm_ref = $req->{'Value'}[0];
        $self->debug_msg(DEBUG_LEVEL_0, "Suspending VM '" . $self->opts->{xen_vmname} . "'...");
        $self->suspend_vm($session, $xen, $vm_ref);
    }
    else {
        my $vm_prefix = $self->opts->{xen_vmname};
        my $vm_number;
        for (1 .. $self->opts->{xen_number_of_vms}) {
            $vm_number = $_;
            $self->opts->{xen_vmname} = $vm_prefix . '_' . $vm_number;

            #-----------------------------------------------------------------------------
            # Get VM ref
            #-----------------------------------------------------------------------------
            $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

            $vm_ref = $req->{'Value'}[0];
            $self->debug_msg(DEBUG_LEVEL_0, "Suspending VM '" . $self->opts->{xen_vmname} . "'...");
            $self->suspend_vm($session, $xen, $vm_ref);
        }
    }

    #-----------------------------------------------------------------------------
    # Logout
    #-----------------------------------------------------------------------------
    $self->logout($session, $xen);
    if ($self->ecode) { return; }

    return;
}

###############################################################################
# suspend_vm - Suspend the specified VM to disk.
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub suspend_vm {
    my ($self, $session, $xen, $vm_ref) = @_;

    #-----------------------------------------------------------------------------
    # Get VM status
    #-----------------------------------------------------------------------------
    my $vmstate = $self->checkStatus($session, $xen, $vm_ref);
    if ($self->ecode) { return; }

    if ($vmstate ne 'Running') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to suspend VM: This can only be called when the specified VM is in the Running state.');
        $self->debug_msg(DEBUG_LEVEL_0, "VM state: " . $vmstate);
        $self->opts->{exitcode} = ERROR;
        return;

    }

    #-----------------------------------------------------------------------------
    # Suspend the VM
    #-----------------------------------------------------------------------------
    my $req = $xen->simple_request('VM.suspend', $session, $vm_ref);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to suspend VM: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    $self->debug_msg(DEBUG_LEVEL_0, 'VM successfully suspended.');
    return;
}

###############################################################################
# resume - Call resume_vm the number of times specified  by ' xen_number_of_vms '
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub resume {
    my ($self) = @_;

    # Initialize
    $self->initialize();
    if ($self->opts->{exitcode}) { return; }
    $self->initialize_prop_prefix;
    if ($self->opts->{exitcode}) { return; }

    #-----------------------------------------------------------------------------
    # Login and get Session
    #-----------------------------------------------------------------------------
    my ($session, $xen) = $self->login();
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Resume
    #-----------------------------------------------------------------------------
    my $req;
    my $vm_ref;
    $self->debug_msg(DEBUG_LEVEL_1, '----------------------------------------------------------------------------------------------------');
    if ($self->opts->{xen_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {

        #-----------------------------------------------------------------------------
        # Get VM ref
        #-----------------------------------------------------------------------------
        $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $vm_ref = $req->{'Value'}[0];
        $self->debug_msg(DEBUG_LEVEL_0, "Resuming VM '" . $self->opts->{xen_vmname} . "'...");
        $self->resume_vm($session, $xen, $vm_ref);
    }
    else {
        my $vm_prefix = $self->opts->{xen_vmname};
        my $vm_number;
        for (1 .. $self->opts->{xen_number_of_vms}) {
            $vm_number = $_;
            $self->opts->{xen_vmname} = $vm_prefix . '_' . $vm_number;

            #-----------------------------------------------------------------------------
            # Get VM ref
            #-----------------------------------------------------------------------------
            $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

            $vm_ref = $req->{'Value'}[0];
            $self->debug_msg(DEBUG_LEVEL_0, "Resuming VM '" . $self->opts->{xen_vmname} . "'...");
            $self->resume_vm($session, $xen, $vm_ref);
        }
    }

    #-----------------------------------------------------------------------------
    # Logout
    #-----------------------------------------------------------------------------
    $self->logout($session, $xen);
    if ($self->ecode) { return; }

    return;
}

###############################################################################
# resume_vm - Awaken the specified VM and resume it.
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub resume_vm {
    my ($self, $session, $xen, $vm_ref) = @_;

    #-----------------------------------------------------------------------------
    # Get VM status
    #-----------------------------------------------------------------------------
    my $vmstate = $self->checkStatus($session, $xen, $vm_ref);
    if ($self->ecode) { return; }

    if ($vmstate ne 'Suspended') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to resume VM: This can only be called when the specified VM is in the Suspended state.');
        $self->debug_msg(DEBUG_LEVEL_0, "VM state: " . $vmstate);
        $self->opts->{exitcode} = ERROR;
        return;

    }

    #-----------------------------------------------------------------------------
    # Resume the VM
    #-----------------------------------------------------------------------------
    my $req = $xen->simple_request('VM.resume', $session, $vm_ref, RPC::XML::boolean->new($self->opts->{xen_start_paused}), RPC::XML::boolean->new($self->opts->{xen_force}));
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to resume VM: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    $self->debug_msg(DEBUG_LEVEL_0, 'VM successfully resumed.');
    return;
}

###############################################################################
# shut_down - Call shutdown_vm the number of times specified  by ' xen_number_of_vms '
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub shut_down {
    my ($self) = @_;

    # Initialize
    $self->initialize();
    if ($self->opts->{exitcode}) { return; }
    $self->initialize_prop_prefix;
    if ($self->opts->{exitcode}) { return; }

    #-----------------------------------------------------------------------------
    # Login and get Session
    #-----------------------------------------------------------------------------
    my ($session, $xen) = $self->login();
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Shutdown
    #-----------------------------------------------------------------------------
    my $req;
    my $vm_ref;
    $self->debug_msg(DEBUG_LEVEL_1, '----------------------------------------------------------------------------------------------------');
    if ($self->opts->{xen_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {

        #-----------------------------------------------------------------------------
        # Get VM ref
        #-----------------------------------------------------------------------------
        $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $vm_ref = $req->{'Value'}[0];
        $self->debug_msg(DEBUG_LEVEL_0, "Shutting down VM '" . $self->opts->{xen_vmname} . "'...");
        $self->shutdown_vm($session, $xen, $vm_ref);
    }
    else {
        my $vm_prefix = $self->opts->{xen_vmname};
        my $vm_number;
        for (1 .. $self->opts->{xen_number_of_vms}) {
            $vm_number = $_;
            $self->opts->{xen_vmname} = $vm_prefix . '_' . $vm_number;

            #-----------------------------------------------------------------------------
            # Get VM ref
            #-----------------------------------------------------------------------------
            $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

            $vm_ref = $req->{'Value'}[0];
            $self->debug_msg(DEBUG_LEVEL_0, "Shutting down VM '" . $self->opts->{xen_vmname} . "'...");
            $self->shutdown_vm($session, $xen, $vm_ref);
        }
    }

    #-----------------------------------------------------------------------------
    # Logout
    #-----------------------------------------------------------------------------
    $self->logout($session, $xen);
    if ($self->ecode) { return; }

    return;
}

###############################################################################
# shutdown_vm - Shut down the specified VM.
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub shutdown_vm {
    my ($self, $session, $xen, $vm_ref) = @_;
    my $req;

    #-----------------------------------------------------------------------------
    # Shutdown the VM
    #-----------------------------------------------------------------------------
    if ($self->opts->{xen_hard_shutdown} eq '1') {
        ##-----------------------------
        ## Hard Shutdown VM
        ##-----------------------------
        $req = $xen->simple_request('VM.hard_shutdown', $session, $vm_ref);
    }
    else {
        ##-----------------------------
        ## Get VM status
        ##-----------------------------
        my $vmstate = $self->checkStatus($session, $xen, $vm_ref);
        if ($self->ecode) { return; }

        #print "$vmstate";
        if ($vmstate ne 'Running') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to shutdown VM: This can only be called when the specified VM is in the Running state.');
            $self->debug_msg(DEBUG_LEVEL_0, "VM state: " . $vmstate);
            $self->opts->{exitcode} = ERROR;
            return;
        }
        ##-----------------------------
        ## Clean Shutdown VM
        ##-----------------------------
        $req = $xen->simple_request('VM.clean_shutdown', $session, $vm_ref);

    }

    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to Shutdown VM: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }
    $self->debug_msg(DEBUG_LEVEL_0, 'VM successfully shutdown.');
    return;
}

###############################################################################
# reboot - Call reboot_vm the number of times specified  by ' xen_number_of_vms '
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub reboot {
    my ($self) = @_;

    # Initialize
    $self->initialize();
    if ($self->opts->{exitcode}) { return; }
    $self->initialize_prop_prefix;
    if ($self->opts->{exitcode}) { return; }

    #-----------------------------------------------------------------------------
    # Login and get Session
    #-----------------------------------------------------------------------------
    my ($session, $xen) = $self->login();
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Reboot
    #-----------------------------------------------------------------------------
    my $req;
    my $vm_ref;
    $self->debug_msg(DEBUG_LEVEL_1, '----------------------------------------------------------------------------------------------------');
    if ($self->opts->{xen_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {

        #-----------------------------------------------------------------------------
        # Get VM ref
        #-----------------------------------------------------------------------------
        $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $vm_ref = $req->{'Value'}[0];
        $self->debug_msg(DEBUG_LEVEL_0, "Rebooting VM '" . $self->opts->{xen_vmname} . "'...");
        $self->reboot_vm($session, $xen, $vm_ref);
    }
    else {
        my $vm_prefix = $self->opts->{xen_vmname};
        my $vm_number;

        for (0 .. $self->opts->{xen_number_of_vms}) {
            $vm_number = $_ + 1;
            $self->opts->{xen_vmname} = $vm_prefix . '_' . $vm_number;

            #-----------------------------------------------------------------------------
            # Get VM ref
            #-----------------------------------------------------------------------------
            $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

            $vm_ref = $req->{'Value'}[0];
            $self->debug_msg(DEBUG_LEVEL_0, "Rebooting VM '" . $self->opts->{xen_vmname} . "'...");
            $self->reboot_vm($session, $xen, $vm_ref);
        }
    }

    #-----------------------------------------------------------------------------
    # Logout
    #-----------------------------------------------------------------------------
    $self->logout($session, $xen);
    if ($self->ecode) { return; }

    return;
}

###############################################################################
# reboot_vm - Reboot the specified VM.
#
# Arguments:
#   none
#
# Returns:
#   none
#
###############################################################################
sub reboot_vm {
    my ($self, $session, $xen, $vm_ref) = @_;
    my $req;

    #-----------------------------------------------------------------------------
    # Reboot the VM
    #-----------------------------------------------------------------------------
    if ($self->opts->{xen_hard_reboot} eq '1') {
        ##-----------------------------
        ## Hard reboot VM
        ##-----------------------------
        $req = $xen->simple_request('VM.hard_reboot', $session, $vm_ref);
    }
    else {
        ##-----------------------------
        ## Get VM status
        ##-----------------------------
        my $vmstate = $self->checkStatus($session, $xen, $vm_ref);
        if ($self->ecode) { return; }

        if ($vmstate ne 'Running') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to reboot VM: This can only be called when the specified VM is in the Running state.');
            $self->debug_msg(DEBUG_LEVEL_0, "VM state: " . $vmstate);
            $self->opts->{exitcode} = ERROR;
            return;
        }
        ##-----------------------------
        ## Clean reboot VM
        ##-----------------------------
        $req = $xen->simple_request('VM.clean_reboot', $session, $vm_ref);
    }

    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to reboot VM: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }

    $self->debug_msg(DEBUG_LEVEL_0, 'VM successfully rebooted.');
    return;
}

###############################################################################
# createResourceFromVM - Initialize and call storeProperties
#
# Arguments:
#   cgfId - configuration ID
#   cfgName - configuration name
#
# Returns:
#   none
#
###############################################################################
sub createResourceFromVM {
    my ($self) = @_;

    # Initialize
    $self->initialize();
    if ($self->opts->{exitcode}) { return; }
    $self->initialize_prop_prefix;
    if ($self->opts->{exitcode}) { return; }

    $self->opts->{xen_createresource} = '1';

    #-----------------------------------------------------------------------------
    # Login and get Session
    #-----------------------------------------------------------------------------
    my ($session, $xen) = $self->login();
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Store Properties and Create Resource
    #-----------------------------------------------------------------------------
    my $req;
    my $vm_ref;
    my $vm_vif;
    $self->debug_msg(DEBUG_LEVEL_1, '----------------------------------------------------------------------------------------------------');
    if ($self->opts->{xen_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {

        #-----------------------------------------------------------------------------
        # Get VM ref
        #-----------------------------------------------------------------------------
        $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $vm_ref = $req->{'Value'}[0];

        #-----------------------------------------------------------------------------
        # Get VM status
        #-----------------------------------------------------------------------------
        my $vmstate = $self->checkStatus($session, $xen, $vm_ref);
        if ($self->ecode) { return; }

        if ($vmstate eq 'Halted') {

            #-----------------------------------------------------------------------------
            # Start VM
            #-----------------------------------------------------------------------------
            $self->start_vm($session, $xen, $vm_ref);
            if ($self->ecode) { return; }

            sleep WAIT_SLEEP_TIME;
            sleep WAIT_SLEEP_TIME;
        }

        #-----------------------------------------------------------------------------
        # Get VM record
        #-----------------------------------------------------------------------------
        $req = $xen->simple_request('VM.get_record', $session, $vm_ref);
        if ($req->{'Status'} eq 'Failure') {
            $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM record: ' . $req->{'ErrorDescription'}[0]);
            $self->opts->{exitcode} = ERROR;
            return;
        }

        $vm_vif = $req->{'Value'}{'VIFs'}[0];

        $self->storeProperties($session, $xen, $vm_ref, $vm_vif);
    }
    else {
        my $vm_prefix = $self->opts->{xen_vmname};
        my $vm_number;
        for (1 .. $self->opts->{xen_number_of_vms}) {
            $vm_number = $_;
            $self->opts->{xen_vmname} = $vm_prefix . '_' . $vm_number;

            #-----------------------------------------------------------------------------
            # Get VM ref
            #-----------------------------------------------------------------------------
            $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

            $vm_ref = $req->{'Value'}[0];

            #-----------------------------------------------------------------------------
            # Get VM record
            #-----------------------------------------------------------------------------
            $req = $xen->simple_request('VM.get_record', $session, $vm_ref);
            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM record: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

            $vm_vif = $req->{'Value'}{'VIFs'}[0];

            $self->storeProperties($session, $xen, $vm_ref, $vm_vif);
        }
    }

    #-----------------------------------------------------------------------------
    # Logout
    #-----------------------------------------------------------------------------
    $self->logout($session, $xen);
    if ($self->ecode) { return; }

    return;

}

###############################################################################
# storeProperties - Save Vm information in properties
#
# Arguments:
#   session    - Xen session_id
#   xen        - RPC::XML::Client instance
#   vm_ref     - Xen VM reference
#
# Returns:
#   none
#
###############################################################################
sub storeProperties {
    my ($self, $session, $xen, $vm_ref, $vm_vif) = @_;

    my $vm_record;
    my $vm_guest_metrics;
    my $req;
    my $vm_name_label;
    my $vm_uuid;
    my $vm_description;
    my $vm_net;
    my $vmNetworkName;
    my $vmMac;
    my $vm_os_version;
    my $vm_ip;
    my $setResult;

    sleep WAIT_SLEEP_TIME;
    sleep WAIT_SLEEP_TIME;

    $self->debug_msg(DEBUG_LEVEL_5, '- Getting information of virtual machine ... ');

    #-----------------------------------------------------------------------------
    # Get VM record
    #-----------------------------------------------------------------------------
    $req = $xen->simple_request('VM.get_record', $session, $vm_ref);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get VM record: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }
    $vm_record = $req->{'Value'};

    $vm_name_label  = $vm_record->{name_label};
    $vm_uuid        = $vm_record->{uuid};
    $vm_description = $vm_record->{name_description};

    #-----------------------------------------------------------------------------
    # Get VM guest metrics
    #-----------------------------------------------------------------------------
    $req = $xen->simple_request('VM.get_guest_metrics', $session, $vm_ref);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get VM guest metrics: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }
    $vm_guest_metrics = $req->{'Value'};
    if ($vm_guest_metrics eq 'OpaqueRef:NULL') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get VM information: ' . 'VM_guest_metrics is empty.');
        $self->opts->{exitcode} = ERROR;
        return;
    }

    #-----------------------------------------------------------------------------
    # Get VM OS version
    #-----------------------------------------------------------------------------
    $req = $xen->simple_request('VM_guest_metrics.get_os_version', $session, $vm_guest_metrics);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get VM OS version: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }
    $vm_os_version = $req->{'Value'};
    $vm_os_version = $vm_os_version->{name};

    #-----------------------------------------------------------------------------
    # Get VM ip address
    #-----------------------------------------------------------------------------
    $req = $xen->simple_request('VM_guest_metrics.get_networks', $session, $vm_guest_metrics);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get VM ip address: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }
    $vm_ip = $req->{'Value'};
    $vm_ip = $vm_ip->{"$::vif/ip"};

    #-----------------------------------------------------------------------------
    # Get VM network name
    #-----------------------------------------------------------------------------
    $req = $xen->simple_request('VIF.get_network', $session, $vm_vif);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get VM network reference: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }
    $vm_net = $req->{'Value'};

    $req = $xen->simple_request('network.get_name_label', $session, $vm_net);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get VM network name: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }
    $vmNetworkName = $req->{'Value'};

    #-----------------------------------------------------------------------------
    # Get VM MAC address
    #-----------------------------------------------------------------------------
    $req = $xen->simple_request('VIF.get_MAC', $session, $vm_vif);
    if ($req->{'Status'} eq 'Failure') {
        $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Error trying to get MAC address: ' . $req->{'ErrorDescription'}[0]);
        $self->opts->{exitcode} = ERROR;
        return;
    }
    $vmMac = $req->{'Value'};

    #-----------------------------------------------------------------------------
    # Store VM information on properties
    #-----------------------------------------------------------------------------
    $self->debug_msg(DEBUG_LEVEL_1, 'Storing properties ... ');

    $setResult = $self->setProp(q{/} . $self->opts->{xen_vmname} . q{/Name},        $vm_name_label);
    $setResult = $self->setProp(q{/} . $self->opts->{xen_vmname} . q{/uuid},        $vm_uuid);
    $setResult = $self->setProp(q{/} . $self->opts->{xen_vmname} . q{/Description}, $vm_description);
    $setResult = $self->setProp(q{/} . $self->opts->{xen_vmname} . q{/Network},     $vmNetworkName);
    $setResult = $self->setProp(q{/} . $self->opts->{xen_vmname} . q{/MACAddress},  $vmMac);
    $setResult = $self->setProp(q{/} . $self->opts->{xen_vmname} . q{/OS_version},  $vm_os_version);
    $setResult = $self->setProp(q{/} . $self->opts->{xen_vmname} . q{/IP_Address},  $vm_ip);
    $setResult = $self->setProp(q{/} . $self->opts->{xen_vmname} . q{/VM_ref},  $vm_ref);

    $self->debug_msg(DEBUG_LEVEL_1, '##################### VM Information #####################');
    $self->debug_msg(DEBUG_LEVEL_1, q{Name: } . $vm_name_label);
    $self->debug_msg(DEBUG_LEVEL_1, q{UUID: } . $vm_uuid);
    $self->debug_msg(DEBUG_LEVEL_1, q{Description: } . $vm_description);
    $self->debug_msg(DEBUG_LEVEL_1, q{Network: } . $vmNetworkName);
    $self->debug_msg(DEBUG_LEVEL_1, q{Mac address: } . $vmMac);
    $self->debug_msg(DEBUG_LEVEL_1, q{OS version: } . $vm_os_version);
    $self->debug_msg(DEBUG_LEVEL_1, q{IP Address: } . $vm_ip);
    $self->debug_msg(DEBUG_LEVEL_1, '##########################################################');

    my $vm_resource = {
                        'name'      => $vm_name_label,
                        'ipAddress' => $vm_ip
                      };

    #-----------------------------------------------------------------------------
    # Create Resource
    #-----------------------------------------------------------------------------
    if ($self->opts->{xen_createresource} eq '1') {

        $self->createResource($vm_resource);
        if ($self->ecode) { return; }

    }

    return;
}

###############################################################################
# createResource - Create Commander resource and save information in properties
#
# Arguments:
#   vm_resource - array containing the VM information
#
# Returns:
#   none
#
###############################################################################
sub createResource {
    my ($self, $vm_resource) = @_;

    my %failedMachines = ();
    my $hostname;
    my $res_name = $vm_resource->{name} . "-" . $self->opts->{JobId} . "-" . $self->opts->{tag};

    #-----------------------------------------------------------------------------
    # Append a generated pool name to any specified
    #-----------------------------------------------------------------------------
    my $pool = $self->opts->{ec_pools} . ' EC-' . $self->opts->{JobStepId};

    if (!defined($vm_resource->{'ipAddress'}) || $vm_resource->{'ipAddress'} eq q{}) {
        $hostname = $vm_resource->{'name'};
    }
    else {
        $hostname = $vm_resource->{'ipAddress'};
    }

    #-----------------------------------------------------------------------------
    # Create resource
    #-----------------------------------------------------------------------------
    $self->debug_msg(DEBUG_LEVEL_0, 'Creating resource for virtual machine \'' . $vm_resource->{name} . '\'...');
    my $cmdrresult = $self->my_cmdr()->createResource(
                                                      'Xen_' . $res_name,
                                                      {
                                                         description   => 'Xen created resource for ' . $vm_resource->{name},
                                                         workspaceName => $self->opts->{ec_workspace},
                                                         hostName      => $hostname,
                                                         pools         => $pool
                                                      }
                                                     );

    #-----------------------------------------------------------------------------
    # Check for error return
    #-----------------------------------------------------------------------------
    my $errMsg = $self->my_cmdr()->checkAllErrors($cmdrresult);
    if ($errMsg ne q{}) {
        $self->debug_msg(DEBUG_LEVEL_0, 'Error: ' . $errMsg);
        $self->opts->{exitcode} = ERROR;
        $failedMachines{$hostname} = 1;
        return;
    }

    $self->debug_msg(DEBUG_LEVEL_0, 'Resource created!!');

    if ("$::resourceList" ne "") { $::resourceList .= ";"; }
    $::resourceList .= 'Xen_' . $res_name;

    #-------------------------------------
    # Record the resource name created
    #-------------------------------------
    #my $setResult = $self->setProp('/resources/' . 'Xen_' . $res_name . '/resName', 'Xen_' . $res_name);
    my $setResult = $self->setProp(q{/} . $vm_resource->{name} . q{/Resource},  'Xen_' . $res_name);

    #-------------------------------------
    # Wait for resource to respong to ping
    #-------------------------------------
    # If creation of resource failed, do not ping
    if (!defined($failedMachines{$hostname})
        || $failedMachines{ $hostname == 0 })
    {

        my $resStarted = 0;
        my $try        = DEFAULT_PINGTIMEOUT;
        while ($try > 0) {
            $self->debug_msg(DEBUG_LEVEL_1, '- Waiting for ping response #(' . $try . ') of resource ' . 'Xen_' . $res_name . "'");
            my $pingresult = $self->pingResource('Xen_' . $res_name);
            if ($pingresult == 1) {
                $resStarted = 1;
                last;
            }
            sleep DEFAULT_SLEEP;
            $try -= 1;
        }
        if ($resStarted == 0) {
            $self->debug_msg(DEBUG_LEVEL_0, '[ERROR] Unable to ping virtual machine');
            $self->opts->{exitcode} = ERROR;
        }
        else {
            $self->debug_msg(DEBUG_LEVEL_1, '- Ping response successfully received');
        }
    }

    return;
}

###############################################################################
# cleanup - Call cleanup_vm the number of times specified  by 'xen_number_of_vms'
#
# Arguments:
#   -
#
# Returns:
#   -
#
###############################################################################
sub cleanup {
    my ($self) = @_;

    # Initialize
    $self->initialize();
    if ($self->opts->{exitcode}) { return; }
    $self->initialize_prop_prefix;
    if ($self->opts->{exitcode}) { return; }

    #-----------------------------------------------------------------------------
    # Login and get Session
    #-----------------------------------------------------------------------------
    my ($session, $xen) = $self->login();
    if ($self->ecode) { return; }

    #-----------------------------------------------------------------------------
    # Cleanup
    #-----------------------------------------------------------------------------
    my $req;
    my $vm_ref;

    ## 1. If results set, search for resources and vms, then get vm names on array
    ##      a. for each vm in array, call cleanup_vm with that name
    ## 2. If results not set, use common(check for number of vms) ...

    if ($::results eq TRUE) {
        my @vms = $self->getDeployedVMListFromProperty();

        foreach my $machineName (@vms) {

            #-----------------------------------------------------------------------------
            # Get VM ref
            #-----------------------------------------------------------------------------
            $req = $xen->simple_request('VM.get_by_name_label', $session, $machineName);

            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

            $vm_ref = $req->{'Value'}[0];
            $self->cleanup_vm($session, $xen, $vm_ref, $machineName);
        }

    }
    else {

        if ($self->opts->{xen_number_of_vms} == DEFAULT_NUMBER_OF_VMS) {

            #-----------------------------------------------------------------------------
            # Get VM ref
            #-----------------------------------------------------------------------------
            $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

            if ($req->{'Status'} eq 'Failure') {
                $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
                $self->opts->{exitcode} = ERROR;
                return;
            }

            $vm_ref = $req->{'Value'}[0];
            $self->cleanup_vm($session, $xen, $vm_ref, $self->opts->{xen_vmname});
        }
        else {
            my $vm_prefix = $self->opts->{xen_vmname};
            my $vm_number;
            for (1 .. $self->opts->{xen_number_of_vms}) {
                $vm_number = $_;
                $self->opts->{xen_vmname} = $vm_prefix . '_' . $vm_number;

                #-----------------------------------------------------------------------------
                # Get VM ref
                #-----------------------------------------------------------------------------
                $req = $xen->simple_request('VM.get_by_name_label', $session, $self->opts->{xen_vmname});

                if ($req->{'Status'} eq 'Failure') {
                    $self->debug_msg(DEBUG_LEVEL_0, 'Error trying to get VM ref: ' . $req->{'ErrorDescription'}[0]);
                    $self->opts->{exitcode} = ERROR;
                    return;
                }

                $vm_ref = $req->{'Value'}[0];

                $self->cleanup_vm($session, $xen, $vm_ref, $self->opts->{xen_vmname});
            }
        }
    }

    #-----------------------------------------------------------------------------
    # Logout
    #-----------------------------------------------------------------------------
    $self->logout($session, $xen);
    if ($self->ecode) { return; }

    return;
}

###############################################################################
# cleanup_vm - shutdown and destroy a VM
#
# Arguments:
#   -
#
# Returns:
#   -
#
###############################################################################
sub cleanup_vm {
    my ($self, $session, $xen, $vm_ref, $vmname) = @_;

    $self->debug_msg(DEBUG_LEVEL_1, '----------------------------------------------------------------------------------------------------');

    #-----------------------------------------------------------------------------
    # Get VM status
    #-----------------------------------------------------------------------------
    my $vmstate = $self->checkStatus($session, $xen, $vm_ref);
    if ($self->ecode) { return; }

    if ($vmstate ne 'Halted') {

        if ($self->opts->{xen_delete} eq '1') {
            $self->opts->{xen_hard_shutdown} = '1';
        }
        else { $self->opts->{xen_hard_shutdown} = '0'; }

        #-----------------------------------------------------------------------------
        # ShutDown VM
        #-----------------------------------------------------------------------------
        $self->shutdown_vm($session, $xen, $vm_ref);
        if ($self->ecode) { return; }

    }

    #-----------------------------------------------------------------------------
    # Delete resource (if created)
    #-----------------------------------------------------------------------------
    my @resources;
    my $tag = $self->opts->{tag};

    if ($::results eq TRUE) {

        #-------------------------------------
        # Get resource info from properties
        #-------------------------------------
        my @resourcesList = $self->getDeployedResourceListFromProperty();

        foreach my $resource (@resourcesList) {
            if ($resource =~ m/Xen_$vmname-([\d]+)-$tag/ixms) {
                $self->debug_msg(DEBUG_LEVEL_1, 'Found deployed resource ' . $resource);
                push @resources, $resource;
            }

        }

    }
    else {

        my $xpath = $self->my_cmdr()->getResources();

        my $nodeset = $xpath->find('//resource');
        foreach my $node ($nodeset->get_nodelist) {
            my $r = $xpath->findvalue('resourceName', $node)->string_value;
            if ($r =~ m/Xen_$vmname-([\d]+)-$tag/ixms) {
                $self->debug_msg(DEBUG_LEVEL_1, 'Found deployed resource ' . $r);
                push @resources, $r;
            }
        }

    }

    $self->debug_msg(DEBUG_LEVEL_1, 'Cleaning up resources');
    foreach my $machineName (@resources) {
        $self->debug_msg(DEBUG_LEVEL_1, 'Deleting resource ' . $machineName);
        my $cmdrresult = $self->my_cmdr()->deleteResource($machineName);

        #-----------------------------------------------------------------------------
        # Check for error return
        #-----------------------------------------------------------------------------
        my $errMsg = $self->my_cmdr()->checkAllErrors($cmdrresult);
        if ($errMsg ne q{}) {
            $self->debug_msg(DEBUG_LEVEL_1, 'Error: ' . $errMsg);
            $self->opts->{exitcode} = ERROR;
            next;
        }
        $self->debug_msg(DEBUG_LEVEL_1, 'Resource deleted');
    }

    #-----------------------------------------------------------------------------
    # Delete VM
    #-----------------------------------------------------------------------------
    if (defined($self->opts->{xen_delete}) && $self->opts->{xen_delete} eq '1') {

        $self->destroy_vm($session, $xen, $vm_ref);
        if ($self->ecode) { return; }
    }

}

1;
