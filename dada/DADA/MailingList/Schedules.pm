package DADA::MailingList::Schedules;
use strict;

use lib qw(
  ../../
  ../../perllib
);

use Carp qw(croak carp);
use DADA::Config qw(!:DEFAULT);

my $t = $DADA::Config::DEBUG_TRACE->{DADA_MailingList_Schedules};

use DADA::MailingList::MessageDrafts;
use DADA::MailingList::Settings; 
use DADA::App::MassSend; 
use DADA::App::Guts; 
use Try::Tiny; 


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
        $self->{ls_obj}->save(
			{
				-settings  => {
					schedule_last_checked_time => time
				}
			}
		);
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
    my $time = time; 
    
    my $r = "Running Schedules for, " . $self->{ls_obj}->param('list_name') . " (" . $self->{list} . ")\n";
       $r .= '-' x 72 . "\n";
       $r .= "Current Server Time:              " . scalar(localtime($time)) . "\n";  
       $r .= "Scheduled Mass Mailings Last Ran: " . scalar(localtime($self->{ls_obj}->param('schedule_last_checked_time')));
	   $r .= " (" . formatted_runtime($time - $self->{ls_obj}->param('schedule_last_checked_time')) . " ago)\n"; 

    my $count = $self->{d_obj}->count({-role => 'schedule'});

    if($count <= 0){ 
        $r .= "* No Schedules currently saved\n";
    }     
    else { 
        $r .= "* $count Schedule(s)\n";
    }
    my $index = $self->{d_obj}->draft_index({-role => 'schedule'});
    
    SCHEDULES: for my $sched(@$index){ 
        
        #$r .= "Raw Paramaters:\n"; 
        #require Data::Dumper; 
        #$r .= Data::Dumper::Dumper($sched);
        
        $r .= "\t* Subject: " . $sched->{Subject} . "\n"; 
        
        if($sched->{schedule_activated} != 1){ 
            $r .= "\t* Schedule is NOT Activated.\n"; 
            next SCHEDULES; 
        } else { 
            $r .= "\t* Schedule is Activated!\n"; 
		}
        
        my $schedule_times = []; 
        
        my $can_use_datetime = DADA::App::Guts::can_use_datetime(); 

        if($sched->{schedule_type} eq 'recurring' && $can_use_datetime == 0){  
            $r .= "Recurring schedule set, but the DateTime CPAN Perl module will need to be installed.\n";
            next SCHEDULES; 
        }
        elsif($sched->{schedule_type} eq 'recurring' && $can_use_datetime == 1){ 
			
			# This is weird validation buuuuuuut
			if(
				   length($sched->{schedule_recurring_ctime_start}) == 0
				|| length($sched->{schedule_recurring_ctime_end}) == 0
				|| length($sched->{schedule_recurring_display_hms}) == 0
				|| length($sched->{schedule_recurring_days}) == 0
			){ 
				$r .= "\t*DateTime information is missing from this schedule\n";
                $r .= "SKIPPING...\n"; 
				
				
				# Send a failure notification
				
				
				next SCHEDULES;
			}
							
            my $d_lt = {
                7 => 'Sunday',
                1 => 'Monday',
                2 => 'Tuesday',
                3 => 'Wednesday',
                4 => 'Thursday',
                5 => 'Friday',
                6 => 'Saturday',
            };
            my $days_str = undef; 
            # use Data::Dumper; 
            # die Dumper($sched->{schedule_recurring_days}); 
            
			for(@{$sched->{schedule_recurring_days}}){ 
                $days_str .= $d_lt->{$_} . ', '; 
            }

            $r .= "\t* This is a *Recurring* mass mailing," . "\n\t\t\t" . 
            "between: " . $sched->{schedule_recurring_displaydatetime_start} . 
            ' and ' . 
            $sched->{schedule_recurring_displaydatetime_end} .  "\n\t\t\t" .
            'on: ' . 
            $days_str ."\n\t\t\t" .
            'at: '  . $sched->{schedule_recurring_display_hms} . "\n"; 
            
            my ($status, $errors, $recurring_scheds)  = $self->recurring_schedule_times(
                {
                    -recurring_time => $sched->{schedule_recurring_display_hms},
                    -days           => $sched->{schedule_recurring_days}, 
                    -start          => $sched->{schedule_recurring_ctime_start}, 
                    -end            => $sched->{schedule_recurring_ctime_end}, 
                }
            ); 
            if($status == 0){ 
                $r .= "Problems calculating recurring schedules - skipping schedule: " . $errors . "\n"; 
				
				# Send a failure notification
				
                next SCHEDULES; 
            }
			
           # require Data::Dumper; 
           # $r .=   Data::Dumper::Dumper($recurring_scheds); 
            
            for(@$recurring_scheds){ 
                if(
                         $_->{ctime} >= ($time - (604_800*2)) 
                    &&   $_->{ctime} <= ($time + (604_800*2)) 
                ){ 
                    push(@$schedule_times, $_->{ctime}); 
                }
            }
            if(scalar @$schedule_times <= 0){ 
                $r .= "\t* No Scheduled Mailing needs to be sent out.\n";                 
            }
            else { 
                #$r .= "\t\t* Approaching/Past Schedule Times:\n";
                #for(@$schedule_times) { 
                #    $r .= "\t\t\t* " . scalar localtime($_) . "\n"; 
                #}
            }
        }
        else { 
            $r .= "\t* Schedule Type: One-Time\n"; 
            push(@$schedule_times, $sched->{schedule_single_ctime}); 
        }
        
        SPECIFIC_SCHEDULES: for my $specific_time(@$schedule_times) { 

			my $ss_r = ''; 
			
            my $end_time; 
			
			# This is sort of awkwardly placed validation... 
            if($sched->{schedule_type} eq 'recurring'){ 
				$end_time = $sched->{schedule_recurring_ctime_end};
            }
            else { 
				if(length($specific_time) == 0){ 
					$ss_r .= "\t* Date and Time is blank for this schedule\n";
	                $ss_r .= "SKIPPING\n"; 
					
					# Send a failure notification
					
					$r .= $ss_r; 
					next SPECIFIC_SCHEDULES;
				}
				else { 
					$end_time = $specific_time; 
				}				
            }
            
			# was this supposed to be sent a day ago? 
            if($end_time < ($time - 86400)) { 
                $ss_r .= "\t* Schedule is too late to run - should have ran " 
				. formatted_runtime($time - $end_time)
				. ' ago.' 
				. "\n"; 
                $ss_r .= "Deactivating Schedule...\n"; 
				
				# Send a failure notification
				
                $self->deactivate_schedule(
                    {
                        -id     => $sched->{id},
                        -role   => $sched->{role},
                        -screen => $sched->{screen},
                    }
                );
				
				$r .= $ss_r; 
				
                next SPECIFIC_SCHEDULES;
            }
            else {     
                $ss_r .= "\t* Schedule runs at: " . scalar localtime($specific_time) . "\n"; 
            }
        
            my $last_checked = $self->{ls_obj}->param('schedule_last_checked_time'); 
                
            if($specific_time > $time){ 
                $ss_r .= "\t\t(" . formatted_runtime($specific_time - $time);
                if($sched->{schedule_type} eq 'recurring'){ 
                    $ss_r .= " from now"; 
                }
				$ss_r .= ")\n";
				
				$r .= $ss_r; 
				
                next SPECIFIC_SCHEDULES; 
            }
        
			
            if($specific_time >= $self->{ls_obj}->param('schedule_last_checked_time')){  
				
                if(
                    $sched->{schedule_type}                                  eq 'recurring'
                 && $sched->{schedule_recurring_only_mass_mail_if_primary_diff} == 1
                ){ 
                    $ss_r .= "\t* Checking message content...\n";
                    my $c_r = $self->{ms_obj}->construct_and_send(
                         {
                             -draft_id   => $sched->{id},
                             -screen     => $sched->{screen},
                             -role       => $sched->{role},,
                             -process    => 1, 
                             -dry_run    => 1, 
                         }
                     );
					 
					 my $is_feed = 0; 
					 
				    if(
						    $sched->{screen} eq 'send_url_email' 
					    && $sched->{content_from} eq 'feed_url'){ 
						
						$is_feed = 1; 
					}
					 
					 #warn '$sched->{screen}'                     . $sched->{screen}; 
					 #warn '$sched->{content_from}'               . $sched->{content_from}; 
					 #warn '$sched->{feed_url_most_recent_entry}' . $sched->{feed_url_most_recent_entry}; 
					 #warn '$c_r->{vars}->{most_recent_entry}'    . $c_r->{vars}->{most_recent_entry}; 
					 #warn '$is_feed' . $is_feed; 
					 
					 if($is_feed == 1) {
						 
						 $ss_r .= "\t\tMessage is created from an RSS/Atom Feed.\n";
						 $ss_r .= "\t\tLooking for entries in the feed that are newer than was previously sent,\n"; 
						 $ss_r .= "rather than comparing checksums.\n\n";
						 
						 if(
							     length($sched->{feed_url_most_recent_entry}) >= 1
							 && $sched->{feed_url_most_recent_entry} >= $c_r->{vars}->{most_recent_entry}
						 ){ 
	                         $ss_r .= "\t\t* No newer feed entries avalable, most recent entry sent published on, " 
							 	. scalar localtime($sched->{feed_url_most_recent_entry})
							    .".\n";
								
								# this won't work, as any entries old than feed_url_most_recent_entry won't actually be reported!
								# . "\nNewest entry in feed published on, " 
								# .  scalar localtime($c_r->{vars}->{most_recent_entry})
								
								
								
	                         warn "No newer feed entries avalable, most recent entry sent published on, " 
							 	. scalar localtime($sched->{feed_url_most_recent_entry}) if $t; 
							undef($c_r);
							
							$r .= $ss_r; 
	                     	next SPECIFIC_SCHEDULES;      
	
						 }
						 else{ 
							 $ss_r .= "\t* Primary content's most recent entry ("
							 	.  scalar localtime($c_r->{vars}->{most_recent_entry})
								. ")  is newer  than the last message that has been sent ("
								. scalar localtime($sched->{feed_url_most_recent_entry})
								. ")\n";
	                         undef($c_r);
						 }
					 }
					 if($is_feed != 1){
	                     if(
						 	defined($c_r->{md5}) 
	                         && defined($sched->{schedule_html_body_checksum})
	                         && $c_r->{md5} eq $sched->{schedule_html_body_checksum}

	                    ) { 
	                            $ss_r .= "\t\t* Primary Content same as previously sent scheduled mass mailing.\n";
	                            $ss_r .= "\t\t* Skipping sending scheduled mass mailing.\n\n"; 
								undef($c_r);
								
								$r .= $ss_r; 
								
	                            next SPECIFIC_SCHEDULES;      
	                     }
	                     else { 
	                         $r .= "\t* Looks good! Primary content is different than last scheduled mass mailing (checksum check).\n";
	                         undef($c_r);
	                     }	 
					 }
					 undef($c_r);
     
      		
				 }
				 
               $ss_r .= "\t\t* Running schedule now!\n";

			   my $c_r = $self->{ms_obj}->construct_and_send(
                    {
                        -draft_id   => $sched->{id},
                        -screen     => $sched->{screen},
                        -role       => $sched->{role},
                        -process    => 1, 
                    }
                );
               if($sched->{schedule_type} eq 'recurring') { 
                   $ss_r .= $self->update_schedule(
                        {
                            -id     => $sched->{id},
                            -role   => $sched->{role},
                            -screen => $sched->{screen},
                            -vars => { 
                                schedule_html_body_checksum => $c_r->{md5}, 
								feed_url_most_recent_entry  => $c_r->{vars}->{most_recent_entry},
                            },
                        }   
                    );
                }
                
				# oh, there it is. 
                if($c_r->{status} == 1){ 
                    my $escaped_mid = $c_r->{mid}; 
                       $escaped_mid =~ s/\>|\<//g; 
                    $ss_r .= "\t* Scheduled Mass Mailing added to the queue, Message ID: $escaped_mid\n"; 
					
					$self->send_schedule_success_notification(
						{ 
							-draft_id   => $sched->{id},
							-mid        => $escaped_mid, 
							-details    => $ss_r,
						}
					);
					
                }
                else { 
					
					# Send a failure notification
					
                    $ss_r .= "\t* Scheduled Mass Mailing not sent, reasons:\n" . $c_r->{errors} . "\n";
                    warn      "Scheduled Mass Mailing not sent, reasons:\n" . $c_r->{errors} . "\n";
                }
                if($sched->{schedule_type} ne 'recurring'){ 
                    $ss_r .= "\t* Deactivating Schedule...\n"; 
                    $self->deactivate_schedule(
                        {
                            -id     => $sched->{id},
                            -role   => $sched->{role},
                            -screen => $sched->{screen},
                        }
                    );
                }
				
				# Don't want to have this sent more than once, right? 
				if(
					$c_r->{status} == 1 
				 && $sched->{schedule_type} eq 'recurring'
				 ){ 
					 
					 $r .= $ss_r; 
					 
					next SCHEDULES;
				}
            }
            
            if($sched->{schedule_type} ne 'recurring'){ 
                if($specific_time < $self->{ls_obj}->param('schedule_last_checked_time')){ 
                    $ss_r .= "\t* Schedule SHOULD have been sent, but wasn't\n";
                    $ss_r .= "\t* Deactivating Schedule...\n"; 
					
					# Send a failure notification
					
             
                    $ss_r .= $self->deactivate_schedule(
                        {
                            -id     => $sched->{id},
                            -role   => $sched->{role},
                            -screen => $sched->{screen},
                        }
                    );
                }
            }
			
			$r .= $ss_r;
        }
	}
    
    $self->{ls_obj}->save(
		{
			-settings  => {
				schedule_last_checked_time => time
			}
		}
	);

    $r .= "\n"; 
    
    if($args->{-verbose} == 1){ 
        print $r; 
    }
    return $r; 
    
}

sub send_schedule_success_notification { 
	my $self = shift; 
	my ($args) = @_; 
	
	# -draft_id   => $sched->{id},
    # -mid        => $escaped_mid, 
	# -details    => $ss_r,

	
	require DADA::App::Messages;
    my $dap = DADA::App::Messages->new(
		{
			-list => $self->{ls_obj}->param('list'),
		}
	);
	$dap->send_out_message(
		{
			-message => 'schedule_success',
			-email   => $self->{ls_obj}->param('list_owner_email'), 
            -tmpl_params => {
                -list_settings_vars       => $self->{ls_obj}->params,
                -list_settings_vars_param => { -dot_it => 1, },
                -vars                     => {
					details => $args->{-details},
                }
            }
		}	
	);
}

sub recurring_schedule_times {
    my $self = shift;
    my ($args) = @_;
    my $r = undef; 
    
    my $status = 1; 
    my $errors = undef; 
    my $times = [];
    
    # require Data::Dumper; 
    # $r .= "args:" . Data::Dumper::Dumper($args); 
    
    my $recurring_time = $args->{-recurring_time};
    my $days           = $args->{-days};
    my $start          = $args->{-start};
    my $end            = $args->{-end};


    try {
        
        require DateTime;
        require DateTime::Event::Recurrence;
        
        my $start_dt = DateTime->from_epoch( epoch => $start );
        my $end_dt   = DateTime->from_epoch( epoch => $end );

        my ( $hours, $minutes, $seconds ) = split( ':', $recurring_time );

        my $day_set = undef;
        my $dates   = [];

        $day_set = DateTime::Event::Recurrence->weekly(
            days    => $days,
            hours   => $hours,
            minutes => $minutes
        );
        my $it = $day_set->iterator(
            start  => $start_dt,
            before => $end_dt,
        );

        while ( my $dt = $it->next() ) {
            push(
                @$times,
                {
                    # date        => $dt->datetime,
                    # localtime => scalar localtime($self->T_datetime_to_ctime($dt->datetime)),
                    ctime         => $self->T_datetime_to_ctime($dt->datetime), 
                }
            );
        }

    } catch {
        $status = 0; 
        $errors = $_; 
    };

    return ($status, $errors, $times);
}

sub T_datetime_to_ctime {
    my $self = shift; 
    my $datetime = shift;
    require Time::Local;
    my ( $date, $time ) = split( 'T', $datetime );
    my ( $year, $month,  $day )    = split( '-', $date );
    my ( $hour, $minute, $second ) = split( ':', $time );
    $second = int( $second - 0.5 );    # no idea.
    my $time = Time::Local::timelocal( $second, $minute, $hour, $day, $month - 1, $year );

    return $time;
}




sub deactivate_schedule {
    
    my $self   = shift; 
    my ($args) = @_; 
    
    require Data::Dumper;
    my $r; 
    # $r .= 'passed args:'; 
    # $r .= Data::Dumper::Dumper($args); 
    
    
    my $local_q = $self->{d_obj}->fetch(
        {
           -id     => $args->{-id}, 
           -role   => $args->{-role},  
           -screen => $args->{-screen},  
        }
    ); 
    
    # deactivate.
    $local_q->param('schedule_activated', 0); 
    
    $self->{d_obj}->save(
        {
            -cgi_obj => $local_q,
            -id      => $args->{-id}, 
            -role    => $args->{-role},  
            -screen  => $args->{-screen},  
        }
    ); 

    return $r; 
   # return 1; 
}



sub update_schedule {
    
    my $r = 'updating schedule,' . "\n"; 
    
    my $self   = shift; 
    my ($args) = @_; 
    my $vars = $args->{-vars}; 
    require Data::Dumper;
    my $r; 
     #$r .= 'update_schedule: passed args:'; 
     #$r .= Data::Dumper::Dumper($args); 
    
    
    my $local_q = $self->{d_obj}->fetch(
        {
           -id     => $args->{-id}, 
           -role   => $args->{-role},  
           -screen => $args->{-screen},  
        }
    ); 
    
    for(keys %$vars){ 
        $r .= $_ . ' => ' . $vars->{$_} . "\n"; 
        $local_q->param($_, $vars->{$_}); 
    }
            
    $self->{d_obj}->save(
        {
            -cgi_obj => $local_q,
            -id      => $args->{-id}, 
            -role    => $args->{-role},  
            -screen  => $args->{-screen},  
        }
    ); 

    $r .= "done!\n\n"; 
    
    return $r; 
   # return 1; 
}


sub DESTROY {}
    
1;