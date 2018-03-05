package Example::Controller::Security;
use Mojo::Base 'Mojolicious::Controller';

use Example::Util qw/rsaEncrypt getUUID hmacSHA256Hex/;

sub get_secret{
  my $self = shift;
  my $validation = $self->validation;
  $validation->required("client_key");
  $validation->required("_t");
  $validation->required("mpKey");
  $validation->required("devType");
  $validation->required("pukey");
  $validation->required("fingerprint");
  my $result = {};
  if($validation->has_error){
    $result = {code => 50100, errorMsg => $validation->{error}};
  }else{
    my $p = $validation->output;
    my $summary = hmacSHA256Hex($p->{client_key}, $p->{mpKey}, $p->{_t}, $p->{devType}, $p->{pukey});
    #require Data::Dumper;
    #$self->app->log->info(Data::Dumper::Dumper $p);
    #$self->app->log->info(Data::Dumper::Dumper $summary);
    if(uc($summary) eq uc($p->{fingerprint})){
      my $server_key = getUUID;
      my $d = {
        server_key_secret => rsaEncrypt(\$p->{pukey}, $server_key),
        time              => time
      };
      $self->session("client_secret", hmacSHA256Hex($p->{client_key}, $server_key, $p->{fingerprint}));
      $d->{token} = $self->session_options->{id};
      $d->{fingerprint} = hmacSHA256Hex($server_key, $d->{token}, $d->{time}, $p->{fingerprint}, $p->{_t});
      $self->session("server_secret", hmacSHA256Hex($server_key, $p->{client_key}, $d->{fingerprint}));
      #$self->app->log->info("server_secret: ". $self->session("server_secret"));
      #$self->app->log->info("client_secret: ". $self->session("client_secret"));
      $result->{dataInfo} = $d;
    }else{
      $result = {code => 50200};
    }
  }
  $self->render(json => $result);
}












1;