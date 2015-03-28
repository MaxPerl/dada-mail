package DADA::MailingList::Schedules;
use strict;

use lib qw(
  ../../
  ../../perllib
);

use Carp qw(croak carp);
use DADA::Config qw(!:DEFAULT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_MessageDrafts};

use DADA::MailingList::MessageDrafts;
use DADA::MailingList::Settings; 
use DADA::App::MassSend; 
use DADA::App::Guts; 



sub new {

    my $class = shift;
    my ($args) = @_;

    my $self = {};
    bless $self, $class;

    $self->_init($args);
    return $self;

}




sub _init {
    my $self = shift;
    my ($args) = @_;

    $self->{list}   = $args->{-list};
    
    $self->{ms_obj} = DADA::App::MassSend->new({-list => $self->{list}}); 
    $self->{d_obj} = DADA::MailingList::MessageDrafts->new( { -list => $self->{list} } );
    
    
    $self->{ls_obj} =  DADA::MailingList::Settings->new( { -list => $self->{list}  } );
    if(!defined($self->{ls_obj}->param('schedule_last_checked_time')) 
    || $self->{ls_obj}->param('schedule_last_checked_time') <= 0){ 
        $self->{ls_obj}->save({schedule_last_checked_time => time});
        undef($self->{ls_obj}); 
        $self->{ls_obj} =  DADA::MailingList::Settings->new( { -list => $self->{list}  } );
    }
    
    
}




sub run_schedules { 

    my $self   = shift; 

    my ($args) = @_; 
    
    if(!exists($args->{-verbose})){ 
        $args->{-verbose} = 0; 
    }
    my $t    = time; 
    
    my $r = "Running Schedules for, " . $self->{list} . "\n";
       $r .= '-' x 72 . "\n";
       $r .= "\t* Current Server Time: " . scalar(localtime($t)) . "\n";  
       $r .= "\t* Schedules Last Run: " . scalar(localtime($self->{ls_obj}->param('schedule_last_checked_time'))) . "\n"; 

    my $count = $self->{d_obj}->count({-role => 'schedule'});

    if($count <= 0){ 
        $r .= "\t* No Schedules currently saved\n";
    }     
    else { 
        $r .= "\t* $count Schedules\n";
    }
    my $index = $self->{d_obj}->draft_index({-role => 'schedule'});
    SCHEDULES: for my $sched(@$index){ 
        $r .= "\n*\t\t Subject: " . $sched->{Subject} . "\n"; 
        
        if($sched->{schedule_activated} != 1){ 
            $r .= "\t\t* Schedule is NOT Activated.\n"; 
            next SCHEDULES; 
            $r .= "\t\t* Schedule is Activated!\n"; 
        }
        
        if($sched->{schedule_time} < ($t - 86400)) { # was this supposed to be sent a day ago? 
            $r .= "\t\t* Schedule is too late to run - should have ran " . formatted_runtime($t - $sched->{schedule_time}) . ' ago.' . "\n"; 
            $r .= "Deactivating Schedule...\n"; 
            $self->deactivate_schedule(
                {
                    -id     => $sched->{id},
                    -role   => $sched->{role},
                    -screen => $sched->{screen},
                }
            );
            next SCHEDULES;
        }
        else {     
            $r .= "\t\t* Schedule to run at: " . $sched->{schedule_localtime} . "\n"; 
        }
        
        
        my $last_checked = $self->{ls_obj}->param('schedule_last_checked_time'); 
                
        if($sched->{schedule_time} > $t){ 
            $r .= "\t\t* Schedule will run " . formatted_runtime($sched->{schedule_time} - $t)   ." from now\n";
            next SCHEDULES; 
        }
        
        if($sched->{schedule_time} >= $self->{ls_obj}->param('schedule_last_checked_time')){ 
            $r .= "\t\t\t* Schedule running now!\n";
            
           my ($status, $errors, $message_id) = $self->{ms_obj}->construct_and_send(
                {
                    -draft_id   => $sched->{id},
                    -screen     => $sched->{screen},
                    -role       => $sched->{role},,
                    -process    => 1, 
                }
            );
            if($status == 1){ 
                $r .= "\t\t* Scheduled Mass Mailing added to the Queue, Message ID: $message_id\n"; 
            }
            else { 
                $r .= "\t\t* PROBLEMS with Mass Mailing:\n$errors\n"; 
            }
            $r .= "\t\t* Deactivating Schedule...\n"; 
            $self->deactivate_schedule(
                {
                    -id     => $sched->{id},
                    -role   => $sched->{role},
                    -screen => $sched->{screen},
                }
            );
             
        }
        if($sched->{schedule_time} < $self->{ls_obj}->param('schedule_last_checked_time')){ 
            $r .= "\t\t* Schedule SHOULD have been sent, but wasn't\n";
            $r .= "\t\t* Deactivating Schedule...\n"; 
             
            $self->deactivate_schedule(
                {
                    -id     => $sched->{id},
                    -role   => $sched->{role},
                    -screen => $sched->{screen},
                }
            );
        }
    }
    
    $self->{ls_obj}->save({schedule_last_checked_time => time});
    
    $r .= "\n"; 
    
    if($args->{-verbose} == 1){ 
        print $r; 
    }
    return $r; 
    
}




sub deactivate_schedule {
    
    my $self   = shift; 
    my ($args) = @_; 
    
    my $local_q = $self->{d_obj}->fetch(
        {
           -id     => $args->{-id}, 
           -role   => $args->{-role},  
           -screen =>  $args->{-screen},  
        }
    ); 
    
    # deactivate.
    $local_q->param('schedule_activated', 0); 
    
    $self->{d_obj}->save(
        {
            -cgi_obj => $local_q,
            -id      => $args->{-id}, 
            -role    => $args->{-role},  
            -screen  =>  $args->{-screen},  
        }
    ); 

    return 1; 
}

sub DESTROY {}
    
1;