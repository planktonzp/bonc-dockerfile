# 常见问题
## Pod没有启动
### 此种情况很多见,一般有 种可能,分项列述
### 1.镜像拉取失败
#### 关键词 **ImagePullFailed**
* 镜像拉取失败是一个比较好解决的问题,在出现这种情况后建议查看一下镜像仓库是否正常运行,仓库内是否有指定的镜像以及本机与镜像仓库之间的网络状况,从而视情况解决问题
* 建议参考docker仓库搭建及测试的方式进行检查,涉及到的命令为
    > docker ps -a | grep $registry_name #此处为仓库名称,以便确认仓库是否运行  
    > docker inspect $registry_name  
    > docker logs $registry_name #此两条命令为查看容器状态及日志,便于确定错误原因  
    > curl $IP:$PORT/v2/_catalog  
    > curl $IP:$PORT/v2/$IMG_NAME/tags/list #检查仓库内是否有指定镜像以及镜像版本
### 2.容器或pod无法启动 
#### 关键词 **CrashBackLoopOff**
* 容器是kubernetes中很重要的一个底层组成部分,如果出现容器无法启动时,那么整个服务将无法被访问,此时就要对故障的服务进行详细检查和错误定位了
* 首先应当查看的即是Pod列表内的restart次数 如果是在一段时间内频繁重启,那么就意味着容器本身在启动时遇到了严重错误,导致容器完全无法对下发的命令进行执行,相反的,如果仅仅是在启动一段时间后出现重启情况,则应当检查容器内执行的进程是否出现异常引起容器意外停止,相关命令如下
    > kubectl get po --namespace=$namespace #不同租户会有不同的服务,用$namespace区分  
    > kubectl describe po --namespace=$namespace $pod_name #查看指定pod的详细信息,从而进一步确定pod内出现的问题  
    > kubectl logs $pod_name --namespace=$namespace #查看当前问题pod是否有日志输出,从日志中判断日志,需要开发人员配合  
### 3.rc控制外的pod无法终止
#### 此情况一般出现在kubernetes的服务升级时,并无关键词
* 升级是kubernetes对服务进行更新的一个机制,在不影响当前服务的情况下(多为多实例,单实例仍会存在服务停止的情况,要根据服务的启动时间来决定)对服务进行更新,但在升级期间,如果出现意外情况(例如使用者点击刷新或多次点击升级按钮有可能会引起服务升级意外终止或多次触发导致),将会引起pod脱离rc控制,从而在后续的升级或删除操作中出现问题  
* 对于脱离rc控制的pod建议进行删除操作,命令如下  
    > kubectl delete po $pod_name --namespace=$namespace #常见的无主pod都可以如此操作,但是建议先按照无法启动的情况进行问题排查,以避免升级出现其他故障  
    > 如果遇到无法删除或者容器错误引起的删除失败,可以追加参数--grace-period=0进行强制删除,但是此操作有可能损坏集群服务,需要慎重操作  
### 4.ceph挂载文件权限问题或无法挂载
#### 关键词 **volume cannot mount**
* 此错误一般出现在有状态服务或者需要存储卷提供文件存储的情况下,需要对存储卷的提供方式进行检查,此处仅简单介绍ceph的情况
* 在ceph中存储系统大致分为**rbd**,**cephfs**,**radosgw**三种,这三种分别在不同的情况下使用,但有一个共同点就是在挂载的时候需要提供源地址和对应用户及用户密钥,kubernetes中利用secret进行密钥的提供,因此此类问题出现时请及时查看secret文件信息及对应的租户是否有权限使用存储卷资源,相关命令为  
    > kubectl get secert --namespace=$namespace #检查命名空间内是否有所需的secert  
    > kubectl get secret $secret_name --namespace=$namespace -o yaml #用yaml格式显示对应的secret内容,方便检查错误
    > 注: secret内的keyring字串是经过base64转码后得到的,在对比时要进行解码


#### 言未尽全,疏漏遗误之处,还请原谅
