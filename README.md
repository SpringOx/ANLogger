ANTracker(统计集成)
=========

This is an integrated statistical framework for better integration or switching multiple statistical platform, has access to UMAnalytics and BaiduMobStatistics, can be very well expand to more platforms, the platform can even customize friendly stand by.

这是一个统计集成框架，用于更好地集成或者切换多个的统计平台，目前已接入友盟统计和百度移动统计，可以非常很好扩展到更多的平台，即使定制平台也能友好支持。

Friend who reading the document, I do not know if you are experiencing mobile applications running statistical platform due to some technical or policy need to migrate, or have own statistical platform needs to be adjusted, or even need to add some logic global, such as support for account id. So, how make a lot of calling code coupling the interface platform be replaced, while how to consider the execution of smoothing and rollback may be a headache. ANTracker are trying for this, ANTracker attempt to isolate the service request and statistical entities, ANTracker sufficient statistical abstract interface mobile business needs, for basic event, label, count, duration, and even tracking page offers clear interface. On the one hand, ANTracker provides a common protocol for statistical entity interface, each statistical entities simply follow the appropriate protocol interface to provide services. More importantly, the statistical entities capable of providing a plurality of services simultaneously, can be increased during the operation to be removed. ANTracker also allows for the isolation of parallel statistical services through well-designed interface, can also be revoked at any time through the switch will isolate. All this, for many business needs statistics, it will be transparent.

阅读该文档的朋友，不知道是否遇到移动应用正在运行的统计平台由于某些技术或者策略的原因需要迁移，又或者拥有了自己的统计平台需要调整，甚至是需要一些全局性的逻辑补充，比如支持帐号id。那么，如何将大量耦合了平台的接口调用代码加以替换，同时又如何支持平滑和回退，都可能会是让人头疼的问题。ANTracker就是为此做了尝试，ANTracker试图隔离业务请求和统计实体，ANTracker充分抽象移动统计业务所需要的接口，从基本事件、标签、计数、时长，乃至页面跟踪均提供了清晰的接口，另一方面，ANTracker为统计实体提供了通用的协议接口，每一个统计实体只需要简单遵循相应的协议接口即可提供服务。更重要的是，多个统计实体能够同时提供服务，运行过程可以增加也可以移除。ANTracker还允许通过精心设计的接口实现对平行的统计服务隔离，也可以随时通过开关将隔离撤销。这一切，对于需要统计的诸多业务来说，都将是透明的。


![Screenshot](https://dl.dropboxusercontent.com/u/59801943/Screenshots/ANTracker-1.png)

![Screenshot](https://dl.dropboxusercontent.com/u/59801943/Screenshots/ANTracker-2.png)



### Usage(用法)

``` objective-c
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 初始化并加载自己定制的统计平台，UM表示友盟，BM表示百度移动，springox(20141108)
        ANUMTracker *umTracker = [[ANUMTracker alloc] init];
        ANBMTracker *bmTracker = [[ANBMTracker alloc] init];
        ANDIYTracker *diyTracker = [[ANDIYTracker alloc] init];
        [ANTrackServer startWithTrackers:[NSArray arrayWithObjects:umTracker, bmTracker, diyTracker, nil]];
    });
```

``` objective-c
    switch (button.tag) {
        case 1:
            // 最基本的统计，由模块Id和eventId组成(平台eventId=模块+event)，springox(20141108)
            [ANTrackServer track:@"ModuleA"
                           event:@"TestEvent1"];
            break;
            
        case 2:
            // 支持带上默认参数的统计，ParamValue是默认参数的一个string值，springox(20141108)
            [ANTrackServer track:@"ModuleB"
                           event:@"TestEvent2"
                           label:@"ParamValue"];
            break;
            
        case 3:
            // 添加累计的一次性统计，accumulation表示一次性统计的累计值，springox(20141108)
            [ANTrackServer track:@"ModuleC"
                           event:@"TestEvent3"
                           label:@"Accumulation"
                    accumulation:10];
            break;
            
        case 4:
            // 添加非整数值时长的统计，durations表示统计的时长，springox(20141108)
            [ANTrackServer track:@"ModuleD"
                           event:@"TestEvent4"
                           label:@"Durations"
                       durations:3.f];
            break;
            
        case 5:
            // 事件开始的统计，支持以默认的标签参数值加以标记该次事件，springox(20141108)
            [ANTrackServer trackEventBegin:@"ModuleE"
                                     event:@"ActivityEvent"
                                     label:@"ParamValue"];
            break;
            
        case 6:
            // 事件结束的统计，支持以默认的标签参数值加以标记该次事件，springox(20141108)
            [ANTrackServer trackEventEnd:@"ModuleE"
                                   event:@"ActivityEvent"
                                   label:@"ParamValue"];
            break;
            
        case 7:
            // 自定义统计Info，springox(20141108)
            [self trackWithTrackInfo];
            break;
        
        case 8:
            // 页面的进入退出的统计例子，springox(20141108)
            [self presentPageController];
            break;
        
        default:
            break;
    }
    
```

``` objective-c
    ANDIYTrackInfo *info = [[ANDIYTrackInfo alloc] initWithType:ANTrackTypeNormal diy:@"This is diy conent!"];
    [ANTrackServer trackWithInfo:info];
```

## Contact(联系)

- [GitHub](https://github.com/SpringOx)
- [Email](jiachunke@gmail.com)
