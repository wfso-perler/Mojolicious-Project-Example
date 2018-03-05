package Example::Plugin::RoutesRegister;
use Mojo::Base 'Mojolicious::Plugin';
use Example::Util qw/hmacSHA256Hex orderEncodeJSON/;
use Mojo::ByteStream 'b';

has permission => sub{{}};
has before_security => sub{shift->permission->{before_security} ||= {}};
has web_before_login => sub{shift->permission->{web_before_login} ||= {}};
has app_before_login => sub{shift->permission->{app_before_login} ||= {}};
has web_after_login => sub{shift->permission->{web_after_login} ||= {}};
has app_after_login => sub{shift->permission->{app_after_login} ||= {}};

sub register{
  my ($self, $app) = @_;
  my $r = $app->routes;
  
  $self->register_root_routes($r);
  
  $self->hook_around_action_permission_check($app);
  
  
  ## 注册权限校验的方法
  my $permission = $self->permission;
  $app->defaults(permission => $permission);
  
  $app->hook(around_dispatch => sub{
      my ($next, $c) = @_;
      return $next->();
    }
  );
  
}

sub hook_around_action_permission_check{
  my ($self, $app) = @_;
  
  $app->hook(around_action => sub{
      my ($next, $c, $action, $last) = @_;
      my $controller = $c->stash->{controller};
      my $method = $c->stash->{action};
      my $key = "$controller\#$method";
      $app->log->info("route name " . $c->match->endpoint->name);
      ## 不需要安全校验的接口
      my $bs = $self->before_security;
      return $next->() if($bs->{$key});
      
      ## web 不需要登录的接口
      my $wbl = $self->web_before_login;
      return $next->() if($wbl->{$key});
      
      
      ## web 需要登录的接口
      my $wal = $self->web_after_login;
      if($wal->{$key}){
        return $next->() if($c->session("agent_user") || $c->session("user"));
        return $c->render(json => {code => 50604});
      }
      
      ## app 不需要登录的接口
      my $abl = $self->app_before_login;
      if($abl->{$key}){
        if($c->session("server_secret") && $c->session("client_secret")){
          
          ## 校验指纹
          my $hash = $c->req->params->to_hash;
          require Data::Dumper;
          
          $app->log->info(Data::Dumper::Dumper($hash));
          my $cdataKey = delete $hash->{dataKey};
          my $sdataKey = hmacSHA256Hex($c->session("client_secret"),
            b(orderEncodeJSON($hash))->encode("utf8"));
          $app->log->info($cdataKey);
          $app->log->info($sdataKey);
          
          ## 如果指纹失败，则提示重新登录
          unless(uc($cdataKey) eq uc($sdataKey)){
            return $c->render(json => {code => 50201});
          }
          
          return $next->();
        }else{
          return $c->render(json => {code => 50203});
        }
      }
      
      ## app 需要登录的接口
      my $aal = $self->app_after_login;
      if($aal->{$key}){
        unless($c->session("server_secret") && $c->session("client_secret")){
          return $c->render(json => {code => 50203});
        }
        
        ## 校验指纹
        my $hash = $c->req->params->to_hash;
        require Data::Dumper;
        
        $app->log->info(Data::Dumper::Dumper($hash));
        my $cdataKey = delete $hash->{dataKey};
        my $sdataKey = hmacSHA256Hex($c->session("client_secret"),
          b(orderEncodeJSON($hash))->encode("utf8"));
        $app->log->info($cdataKey);
        $app->log->info($sdataKey);
        ## 如果指纹失败，则提示重新登录
        unless(uc($cdataKey) eq uc($sdataKey)){
          return $c->render(json => {code => 50201});
        }
        
        unless($c->session("user")){
          return $c->render(json => {code => 50604});
        }
        return $next->();
      }
      
      ## 其他未说明权限的接口
      return $next->();
    }
  );
}


sub register_root_routes{
  my ($self, $r) = @_;
  
  $r->any([] => '/')->to('example#index');
  $self->set_web_before_login('example#index');
  
  $r->any([] => '/test')->to('example#test');
  $r->any([] => '/debug')->to('example#debug');
  $self->set_web_before_login('example#debug');
  
  $r->any([] => '/api/security/get_secret')->to('security#get_secret');
  $self->set_before_security('security#get_secret');
  
  $r->any([] => '/api/get_table')->to('example#get_table');
  $self->set_web_before_login('example#get_table');
}


sub set_before_security{
  my $self = shift;
  my $route = shift;
  $self->before_security->{$route} = 1;
}


sub set_web_before_login{
  my $self = shift;
  my $route = shift;
  $self->web_before_login->{$route} = 1;
}


sub set_web_after_login{
  my $self = shift;
  my $route = shift;
  $self->web_after_login->{$route} = 1;
}

sub set_app_before_login{
  my $self = shift;
  my $route = shift;
  $self->app_before_login->{$route} = 1;
}


sub set_app_after_login{
  my $self = shift;
  my $route = shift;
  $self->app_after_login->{$route} = 1;
}





1;