package Example::Plugin::JsonResultDefaultValues;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File 'path';
use Mojo::Util qw/decode/;
use Example::Util qw/hmacSHA256Hex orderEncodeJSON/;
use Mojo::ByteStream 'b';

sub register{
  my ($self, $app, $conf) = @_;
  my $home = $app->home;
  my $file = $conf->{file} || $app->config->{status_file} || $home->child('config', $app->moniker . ".status");
  $file = $home->child($file) unless(path($file)->is_abs);
  my $status = {};
  if(-e $file){ $status = $self->load($file, $conf, $app) }
  $app->defaults(status_code => $status);
  $app->helper(debug => sub{
      shift->app->log->info(@_);
    });
  $app->helper("result.status" => sub{$status});
  $app->hook(before_render => sub{
      my ($c, $args) = @_;
      my $json = $args->{json} || $args->{result};
      if($json){
        my $status_code = int($json->{code} = $json->{code} || $status->{default});
        my $curr_status = $status->{$status_code};
        if($curr_status){
          $json->{status} = $curr_status->{status};
          $json->{msg} = $curr_status->{msg};
        }else{
          $json->{status} = "NONE";
          $json->{msg} = "status not found";
        }
        $json->{time} = time;
        $json->{callback} = $c->param("callback") if($c->param("callback"));
        $json->{flag} = $c->param("flag") if($c->param("flag"));
        
        ## $c->app->log->info("----------------dataInfo string--------------:" . b(orderEncodeJSON($json->{dataInfo})) . "--" . $json->{time});
        if($c->session("server_secret")){
          $json->{dataKey} = hmacSHA256Hex($c->session("server_secret"),
            b(orderEncodeJSON($json->{dataInfo}))->encode("utf8")
            , "--", $json->{time});
        }else{
          $json->{dataKey} = hmacSHA256Hex($json->{time}, b(orderEncodeJSON($json->{dataInfo}))->encode("utf8"), "--",
            $json->{time});
        }
        ## $c->app->log->info("-----------datakey--------------:" . $json->{dataKey});
        
      }
    });
  
}

sub load{ $_[0]->parse(decode('UTF-8', path($_[1])->slurp), @_[1, 2, 3]) }

sub parse{
  my ($self, $content, $file, $conf, $app) = @_;
  
  # Run Perl code in sandbox
  my $config = eval 'package Mojolicious::Plugin::JsonResultDefaultValues::Sandbox; no warnings;'
    . "sub app; local *app = sub { \$app }; use Mojo::Base -strict; $content";
  die qq{Can't load StatusCode configuration from file "$file": $@} if($@);
  die qq{StatusCode Configuration file "$file" did not return a hash reference.\n}
    unless(ref $config eq 'HASH');
  
  return $config;
}

1;