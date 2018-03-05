package Example::Plugin::RouteAndPermission;
use Mojo::Base 'Mojolicious::Plugin';
use Example::Util qw/hmacSHA256Hex orderEncodeJSON/;
use Mojo::ByteStream 'b';
use Scalar::Util qw/weaken/;


has ['current_permission_group', 'app'];
has recreate_permission => 1;

sub register{
  my ($self, $app) = @_;
  
  ## 注册属性
  $self->app($app);
  weaken $self->{app};
  
  ## 获取根路由
  my $r = $app->routes;
  
  ## 判断是否需要创建路由
  $self->recreate_permission(1) if($app->config->{recreate_permission});
  my $ps = $app->service("Permission");
  $self->recreate_permission(1) unless($ps->mcount);
  
  
  
  ## 注册路由
  $self->register_root_routes($r);
  
  ## 注册权限判断的hook
  $self->hook_around_action_permission_check($app);
  
  $app->hook(around_dispatch => sub{
      my ($next, $c) = @_;
      return $next->();
    }
  );
  
}


sub register_root_routes{
  my ($self, $r) = @_;
  my $rcp = $self->recreate_permission;
  
  ## 添加一个权限组
  $self->add_permission_group("root", 1) if($rcp);
  
  my $xr;
  $xr = $r->any([] => '/mobile/location' => "手机号归属地")->to('mobile#location');
  $self->add_permission($xr, 1) if($rcp);
  
  $xr = $r->any([] => '/id_card/location' => "身份证号归属地")->to('IDCard#location');
  $self->add_permission($xr, 1) if($rcp);
  
  $xr = $r->any([] => '/debug' => "调试接口")->to('home#debug');
  $self->add_permission($xr, 1) if($rcp);
  
}


sub hook_around_action_permission_check{
  my ($self, $app) = @_;
  
  $app->hook(around_action => sub{
      my ($next, $c, $action, $last) = @_;
      my $controller = $c->stash->{controller};
      my $method = $c->stash->{action};
      my $key = "$controller\#$method";
      $app->log->info("route name " . $c->match->endpoint->name);
      
      ## 其他未说明权限的接口
      return $next->();
    }
  );
}

sub add_permission_group{
  my $self = shift;
  my $group_name = shift;
  my $group_status = shift;
  my $group_intro = shift;
  
  ## 构造group对象
  my $group = {
    group_name   => $group_name,
    group_status => $group_status,
    update_type  => 1
  };
  
  ## 如果有group_intro 则加入对象，建议不要在程序中设置此参数
  $group->{group_intro} = $group_intro if($group_intro);
  my $ps = $self->app->service("Permission");
  
  my $og = $ps->get_permission_group_by_group_name($group->{group_name});
  
  ## 如果已经存在同名的分组，则更新
  if($og && @{$og}){
    $group->{group_id} = $og->[0]->{group_id};
    $ps->medit_permission_group($group);
  }
  ## 如果不同名的分组，则添加
  else{
    $group->{create_type} = 1;
    $group = $ps->mcreate_permission_group($group);
  }
  
  $self->current_permission_group($group);
  
}



sub add_permission{
  my $self = shift;
  my $route = shift;
  my $permission_status = shift;
  my $permission_intro = shift;
  
  ## 计算 code
  my $via = "";
  if($route->via){
    for(@{$route->via}){
      $via .= length($via) ? "_" . $_ : $_;
    }
  }
  my $permission_code = ($via ? $via . "-" : "") . $route->name;
  
  ## 构造 permission 对象
  my $permission = {
    permission_code   => $permission_code,
    permission_name   => $permission_code,
    permission_status => $permission_status,
    group_id          => $self->current_permission_group->{group_id},
    update_type       => 1
  };
  
  ## 如果有group_intro 则加入对象，建议不要在程序中设置此参数
  $permission->{permission_intro} = $permission_intro if($permission_intro);
  
  ## 获取权限管理的service
  my $ps = $self->app->service("Permission");
  
  my $op = $ps->get_by_id($permission->{permission_code});
  
  ## 如果已经存在相同code的permission，则更新
  if($op){
    $ps->medit($permission);
  }
  ## 如果不存在相同code的permission，则添加
  else{
    $permission->{create_type} = 1;
    $permission = $ps->mcreate($permission);
  }
  
}



1;