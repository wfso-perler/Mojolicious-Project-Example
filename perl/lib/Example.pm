package Example;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by "my_app.conf"
  my $config = $self->plugin('Config', {
      file => $self->home->child("config", $self->moniker . ".conf")
    }
  );
  
  ## 设置日志等级
  $self->log->level("debug");
  
  ## 设置应用程序密码
  $self->secrets($config->{secrets});
  
  ## 加载系统插件
  $self->plugin("DBIxCustom");
  $self->plugin("Service");
  $self->plugin("ServerInfo");
  $self->plugin("SessionStorage", {
      cookie_name        => "YOCARDSESSID",
      session_store      => $self->service("SessionFile"),
      default_expiration => 600000000
    }
  );
  
  ## 设置自定义插件包名
  push(@{$self->plugins->namespaces}, "Example::Plugin");
  ## 加载自定义插件
  $self->plugin("ExtendValidator");
  $self->plugin("JsonResultDefaultValues");
  $self->plugin("RoutesRegister");
  $self->plugin("Paging",{default_pre_page=>15});

  ## 关闭文档渲染
  # Documentation browser under "/perldoc"
  # $self->plugin('PODRenderer') if $config->{perldoc};

 
}

1;
