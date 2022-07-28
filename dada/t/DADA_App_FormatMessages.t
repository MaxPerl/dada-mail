#!/usr/bin/perl
use strict; 

use lib qw(./t ./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib ); 
BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 
dada_test_config::create_SQLite_db(); 

use Test::More qw(no_plan);  


my ($entity, $filename, $t_msg); 


use DADA::Config; 
use DADA::App::FormatMessages; 

use DADA::MailingList::Subscribers; 
use DADA::MailingList::Settings; 
use DADA::App::Guts; 

my $list = dada_test_config::create_test_list;
my $ls   = DADA::MailingList::Settings->new({-list => $list}); 


# _add_opener_image
$ls->save(
	{
		-settings => {
			tracker_track_email => 1
		}
	}
);
	
my $fm = DADA::App::FormatMessages->new(-List => $list); 


my $c = 'blah blah blah'; 
$c = $fm->_add_opener_image($c); 
diag $c; 
like($c, qr/open_img/); 
undef $c; 

my $c = q{ 
<html>
<body> 
	Blah Balh Blah.
};
$c = $fm->_add_opener_image($c); 
#diag $c; 
like($c, qr/open_img/); 
undef $c; 


my $c = q{ 
<html>
<body> 
	Blah Balh Blah.
</body> 
</html> 

};
$c = $fm->_add_opener_image($c); 
#diag $c; 
like($c, qr/open_img/); 
undef $c;

#/ _add_opener_image


$filename = 't/corpus/email_messages/simple_template.txt';
#open my $MSG, '<', $filename or die $!; 
#my $msg1 = do { local $/; <$MSG> }  or die $!; 
#close $MSG  or die $!; 

my $msg1 = slurp($filename);
### get_entity 


$entity = $fm->get_entity(
    {
        -data => Encode::encode($DADA::Config::HTML_CHARSET, $msg1),
    }
);
ok($entity->isa('MIME::Entity'));

undef $entity; 

$entity = $fm->get_entity(
    {
        -data          => $filename,
        -parser_params => {-input_mechanism => 'parse_open'},
    }
);

ok($entity->isa('MIME::Entity'));

###/ get_entity



### email_template
my $new_entity; 


$entity = $fm->email_template({-entity => $entity});
ok($entity->isa('MIME::Entity'));
undef $entity; 





$entity = $fm->get_entity(
    {
        -data => Encode::encode($DADA::Config::HTML_CHARSET, $msg1),
    }
);
ok($entity->isa('MIME::Entity'));
$entity = $fm->email_template(
    {
        -entity => $entity,
        -vars   => {
                    from_phrase => 'From Phrase',
                    to_phrase   => 'To Phrase', 
                    subject     => 'This is the subject', 
                    var1        => 'Variable 1', 
                    var2        => 'Variable 2', 
                    var3        => 'Variable 3', 
                    },
    }
);
ok($entity->isa('MIME::Entity'));

$t_msg = $entity->as_string; 
$t_msg = Encode::decode('UTF-8', $t_msg); 


like($t_msg, qr/Subject: This is the subject/); 
like($t_msg, qr/From: "From Phrase" <from\@example.com/);
like($t_msg, qr/To: "To Phrase" <to\@example.com>/); 
like($t_msg, qr/Var1: Variable 1/); 
like($t_msg, qr/Var2: Variable 2/);
like($t_msg, qr/Var3: Variable 3/);
undef $t_msg; 
undef $entity;
undef $filename; 

### / email_template

 

# Multipart/Alternative Message...
$filename = 't/corpus/email_messages/multipart_alternative_template.txt';
$entity = $fm->get_entity(
    {
        -data          => $filename,
        -parser_params => {-input_mechanism => 'parse_open'},
    }
);

ok($entity->isa('MIME::Entity'));

###/ get_entity

$entity = $fm->email_template(
    {
        -entity => $entity,
        -vars   => {
                    from_phrase => 'From Phrase',
                    to_phrase   => 'To Phrase', 
                    subject     => 'This is the subject', 
                    var1        => 'Variable 1', 
                    var2        => 'Variable 2', 
                    var3        => 'Variable 3', 
                    },
    }
);
ok($entity->isa('MIME::Entity'));

$t_msg = $entity->as_string; 

like($t_msg, qr/Subject: This is the subject/); 
like($t_msg, qr/From: "From Phrase" <from\@example.com/);
like($t_msg, qr/To: "To Phrase" <to\@example.com>/); 
like($t_msg, qr/Var1: Variable 1/); 
like($t_msg, qr/Var2: Variable 2/);
like($t_msg, qr/Var3: Variable 3/);
like($t_msg, qr/<p>Var1: Variable 1<\/p>/);
like($t_msg, qr/<p>Var2: Variable 2<\/p>/);
like($t_msg, qr/<p>Var3: Variable 3<\/p>/);
undef $t_msg; 
undef $entity; 
undef $filename; 



# Multipart/Mixed Message...
$filename = 't/corpus/email_messages/simple_template_with_attachment.txt';
$entity = $fm->get_entity(
    {
        -data          => $filename,
        -parser_params => {-input_mechanism => 'parse_open'},
    }
);

ok($entity->isa('MIME::Entity'));

###/ get_entity

$entity = $fm->email_template(
    {
        -entity => $entity,
        -vars   => {
                    from_phrase => 'From Phrase',
                    to_phrase   => 'To Phrase', 
                    subject     => 'This is the subject', 
                    var1        => 'Variable 1', 
                    var2        => 'Variable 2', 
                    var3        => 'Variable 3', 
                    },
    }
);
ok($entity->isa('MIME::Entity'));

$t_msg = $entity->as_string; 

like($t_msg, qr/Subject: This is the subject/); 
like($t_msg, qr/From: "From Phrase" <from\@example.com/);
like($t_msg, qr/To: "To Phrase" <to\@example.com>/); 
like($t_msg, qr/Var1: Variable 1/); 
like($t_msg, qr/Var2: Variable 2/);
like($t_msg, qr/Var3: Variable 3/);


# These are to make sure the variables aren't being decoded, templated out and then encoded. 
#Base64 [var1]
like($t_msg, qr/W3ZhcjFd/); 

#Base 64 Variable 1
unlike($t_msg, qr/VmFyaWFibGUgMQ==/); 

undef $t_msg; 
undef $entity; 
undef $filename; 






# Multipart/Mixed with plaintext attachment
$filename = 't/corpus/email_messages/simple_message_with_plaintext_attachment.txt';
$entity = $fm->get_entity(
    {
        -data          => $filename,
        -parser_params => {-input_mechanism => 'parse_open'},
    }
);

ok($entity->isa('MIME::Entity'));

###/ get_entity

$entity = $fm->email_template(
    {
        -entity => $entity,
        -vars   => {
                    from_phrase => 'From Phrase',
                    to_phrase   => 'To Phrase', 
                    subject     => 'This is the subject', 
                    var1        => 'Variable 1', 
                    var2        => 'Variable 2', 
                    var3        => 'Variable 3', 
                    },
    }
);
ok($entity->isa('MIME::Entity'));

$t_msg = $entity->as_string; 

like($t_msg, qr/Subject: This is the subject/); 
like($t_msg, qr/From: "From Phrase" <from\@example.com/);
like($t_msg, qr/To: "To Phrase" <to\@example.com>/); 
like($t_msg, qr/Var1: Variable 1/); 
like($t_msg, qr/Var2: Variable 2/);
like($t_msg, qr/Var3: Variable 3/);

my $look = quotemeta('rfc822<!-- tmpl_var var1 -->rfc822'); 

unlike($t_msg, qr/$look/); 
like($t_msg, qr/rfc822Variable 1rfc822/);

undef $t_msg; 
undef $entity; 
undef $filename; 


# PlainText Message with a encoding of, "quoted-printable.

$filename = 't/corpus/email_messages/simple_message_quoted_printable.txt';
$entity = $fm->get_entity(
    {
        -data          => $filename,
        -parser_params => {-input_mechanism => 'parse_open'},
    }
);

ok($entity->isa('MIME::Entity'));

###/ get_entity

$entity = $fm->email_template(
    {
        -entity => $entity,
        -vars   => {
                    from_phrase => 'From Phrase',
                    to_phrase   => 'To Phrase', 
                    subject     => 'This is the subject', 
                    var1        => 'Variable 1', 
                    var2        => 'Variable 2', 
                    var3        => 'Variable 3', 
                    },
    }
);
ok($entity->isa('MIME::Entity'));

$t_msg = $entity->as_string; 
$t_msg = Encode::decode('UTF-8', $t_msg); 
diag $t_msg;
like($t_msg, qr/Subject: This is the subject/); 
like($t_msg, qr/From: "From Phrase" <from\@example.com/);
like($t_msg, qr/To: "To Phrase" <to\@example.com>/); 
like($t_msg, qr/Var1: Va\=\nriable 1/); 
like($t_msg, qr/Var2: Va\=\nriable 2/); 
like($t_msg, qr/Var3: Va\=\nriable 3/); 


undef $t_msg; 
undef $entity; 
undef $filename;
 


###########
#
#
# 



$ls->param('prefix_list_name_to_subject', 1); 
$ls->param('prefix_discussion_list_subjects_with', 'list_name'); 

undef $fm; 
my $fm = DADA::App::FormatMessages->new(-List => $list);


my $prefix = '['.$ls->param('list_name').']'; 
my $og_s           =                     'Subject';
my        $subject = $fm->_encode_header('Subject', $og_s); 
my $prefix_subject = $fm->_encode_header('Subject', $prefix . ' ' . $og_s); 

$subject = $fm->_list_name_subject($subject); 
#diag '$subject' . $subject; 
#diag '$prefix_subject' . $prefix_subject; 

diag safely_encode($fm->_decode_header($subject));

diag safely_encode($fm->_decode_header($prefix_subject));


$prefix_subject = quotemeta($prefix_subject); 
like($subject, qr/$prefix_subject/, "Subject set correctly (list name)");
undef $fm; 




$ls->param('prefix_discussion_list_subjects_with', 'list_shortname'); 
$fm = DADA::App::FormatMessages->new(-List => $list);


my $prefix = quotemeta('['.$ls->param('list').']'); 
my $og_s           =                     'Subject';
my        $subject = $fm->_encode_header('Subject', $og_s); 
my $prefix_subject = $fm->_encode_header('Subject', $prefix . ' ' . $og_s); 

$subject = $fm->_list_name_subject($subject); 
#diag '$subject' . $subject; 
#diag '$prefix_subject' . $prefix_subject; 
like($subject, qr/$prefix_subject/, "Subject set correctly (list name)");
undef $fm; 


$fm = DADA::App::FormatMessages->new(-List => $list);
 
        $subject = 'Re: [' . $ls->param('list') . '] Subject';
my $new_subject = quotemeta('Re: [' . $ls->param('list') . '] Subject'); 


#diag q{$fm->_list_name_subject($subject)} . $fm->_list_name_subject($subject); 
#diag q{'[' . $ls->param('list') . '] Re: Subject'} . '[' . $ls->param('list') . '] Re: Subject'; 

like($fm->_list_name_subject($subject), qr/$new_subject/, "Subject set correctly with reply 1"); 
undef $fm; 
undef $new_subject; 




## BIG TODO: 
#
#eval { 
#	
#	like($fm->_list_name_subject($subject), qr/$new_subject/, "Subject set correctly with reply for, 'list_name'"); 

#};
#diag $@ if $@; 

undef $fm; 


# Dadamail 3.0 strips out [endif]
# http://sourceforge.net/tracker2/?func=detail&aid=2030573&group_id=13002&atid=113002
# For now, my fix is to just put *back* the, [endif] tag by having a global 
# tmpl var for the [endif] tag with a value of... [endif] - cheap, but I don't
# quite know what to do instead... 

my $html = slurp('t/corpus/html/outlook.html');
my $simple_email = qq{Content-type: text/html
Subject: Hello

$html
};

$fm = DADA::App::FormatMessages->new(-yeah_no_list => 1); 
$entity = $fm->get_entity(
    {
        -data => Encode::encode($DADA::Config::HTML_CHARSET, $simple_email),
    }
);
ok($entity->isa('MIME::Entity'));
$entity = $fm->email_template(
    {
        -entity => $entity,
        -vars   => {},
    }
);
ok($entity->isa('MIME::Entity'));
$t_msg = $entity->as_string; 
my $endif = quotemeta('[endif]'); 

diag '$endif ' . $endif; 
ok($t_msg =~ m/$endif/,'found the [endif] tag'); 

##
## can_find_unsub_link
#ok(
#    $fm->can_find_unsub_link(
#        { -str => $DADA::Config::MAILING_LIST_MESSAGE }
#    ),
#    "found unsub link in text  mailing list message!"
#);
#
## can_find_unsub_link
#ok(
#    $fm->can_find_unsub_link(
#        { -str => $DADA::Config::MAILING_LIST_MESSAGE_HTML }
#    ),
#    "found unsub link in html mailing list message!"
#);
#ok(
#    $fm->can_find_unsub_link(
#        { -str => $DADA::Config::LIST_SETUP_DEFAULTS{mailing_list_message} }
#    ),
#    "found unsub link in text  mailing list message(2)!"
#);
#ok(
#    $fm->can_find_unsub_link(
#        {
#            -str =>
#              $DADA::Config::LIST_SETUP_DEFAULTS{mailing_list_message_html}
#        }
#    ),
#    "found unsub link in html mailing list message(2)!"
#);
undef($fm); 
$fm = DADA::App::FormatMessages->new(-List => $list);

ok( $fm->can_find_unsub_link( { -str => 'nothing', } ) == 0,
    "but not in a random string" );
ok(
    $fm->can_find_unsub_link(
        {
            -str =>
              $fm->unsubscriptionation( { -str => 'nothin', -type => 'text' } ),
        }
    ),
    "except when checked and placed in, if it's missing"
);

$ls->param('private_list', 1); 
undef($fm); 
$fm = DADA::App::FormatMessages->new(-List => $list);


ok(
    $fm->can_find_unsub_link(
        {
            -str =>
              $fm->unsubscriptionation( { -str => 'nothin', -type => 'text' } ),
        }
    )  ==  0,
    "except when checked and placed in, if it's missing"
);


# can_find_sub_confirm_link
# Should be in list invitation message and subscription confirmation message:

#ok(
#    $fm->can_find_sub_confirm_link(
#        { -str => $DADA::Config::TEXT_INVITE_MESSAGE, }
#    ),
#    "found sub confirm link in text invite message!"
#);
#
#ok(
#    $fm->can_find_sub_confirm_link(
#        { -str => $DADA::Config::HTML_INVITE_MESSAGE, }
#    ),
#    "found sub confirm link in html invite message!"
#);
#
#ok(
#    $fm->can_find_sub_confirm_link(
#        { -str => $DADA::Config::CONFIRMATION_MESSAGE, }
#    ),
#    "found sub confirm link in sub confirm message!"
#);
#
#ok(
#    $fm->can_find_sub_confirm_link(
#        { -str => $DADA::Config::LIST_SETUP_DEFAULTS{confirmation_message}, }
#    ),
#    "found sub confirm link in sub confirm message(2)!"
#);

ok( $fm->can_find_sub_confirm_link( { -str => 'nothin', } ) == 0,
    "did not find it in random string" );

#diag $fm->subscription_confirmationation({-str => 'nothin'});
ok(
    $fm->can_find_sub_confirm_link(
        {
            -str => $fm->subscription_confirmationation( { -str => 'nothin' } ),
        }
    ),
    "but did find it, once string was run through the ation thing"
);

## unsub confirm email
#ok(
#    $fm->can_find_unsub_confirm_link(
#        { -str => $DADA::Config::UNSUBSCRIPTION_REQUEST_MESSAGE, }
#    ),
#    "found unsub confirm link in html mailing list message!"
#);

ok( $fm->can_find_unsub_confirm_link( { -str => 'nothing', } ) == 0,
    "but not in a random string" );
ok(
    $fm->can_find_unsub_confirm_link(
        {
            -str =>
              $fm->unsubscription_confirmationation( { -str => 'nothin' } ),
        }
    ),
    "except when checked and placed in, if it's missing"
);

# _pp mode work for MIME Words encoded stuff? 
my $From_header = '=?UTF-8?Q?=C3=9F=E2=80=A0=C2=AE=C3=B1g=C3=A9_=C3=9F=C3=BCb=C3=9F=C2=AE=C3=AEb=C3=A9=C2=AE?= <weird.subscriber@example.com>'; 
my $From_header_ppd = 
q{"=?UTF-8?Q?=C3=9F=E2=80=A0=C2=AE=C3=B1g=C3=A9_=C3=9F=C3=BCb=C3=9F=C2=AE?=
 =?UTF-8?Q?=C3=AEb=C3=A9=C2=AE?= p.p. Dada Test =?UTF-8?Q?List=C2=A1?=
 =?UTF-8?Q?=E2=84=A2=C2=A3=C2=A2=E2=88=9E=C2=A7=C2=B6=E2=80=A2=C2=AA=C2=BA?=" <test@example.com> (weird.subscriber _at_ example.com)}; 
diag "'" . $fm->_pp($From_header) . "'"; 
#ok($fm->_pp($From_header) eq $From_header_ppd); 



dada_test_config::remove_test_list;
dada_test_config::destroy_SQLite_db();
dada_test_config::wipe_out;


sub slurp { 
	
		
		my ($file) = @_;

        local($/) = wantarray ? $/ : undef;
        local(*F);
        my $r;
        my (@r);

        open(F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')',  $file) || die "open $file: $!";
        @r = <F>;
        close(F) || die "close $file: $!";

        return $r[0] unless wantarray;
        return @r;

}


