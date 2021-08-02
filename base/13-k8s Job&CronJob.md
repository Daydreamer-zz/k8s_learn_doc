
# k8s Job&CronJob

## 1.1 Job概念

Job 会创建一个或者多个 Pods，并将继续重试 Pods 的执行，直到指定数量的 Pods 成功终止。 随着 Pods 成功结束，Job 跟踪记录成功完成的 Pods 个数。 当数量达到指定的成功个数阈值时，任务（即 Job）结束。 删除 Job 的操作会清除所创建的全部 Pods。 挂起 Job 的操作会删除 Job 的所有活跃 Pod，直到 Job 被再次恢复执行。

当第一个 Pod 失败或者被删除（比如因为节点硬件失效或者重启）时，Job 对象会启动一个新的 Pod。

你也可以使用 Job 以并行的方式运行多个 Pod。

## 1.2 Job资源关键字段

- spec.ttlSecondsAfterFinished：Job在执行结束之后（状态为completed或Failed）自动清理。设置为0表示执行结束立即删除，不设置则不会清除，需要开启TTLAfterFinished特性
- spec.backoffLimit：如果任务执行失败，失败多少次后不再执行
- spec.completions：多少个pod执行成功，才认为该Job是成功的
- spec.parallelism：并行执行任务的数量。如果parallelism数值大于未完成任务数，只会创建未完成的数量，比如completions是4，并发是3，第一次会创建3个Pod执行任务，第二次只会创建一个Pod执行任务

## 1.3 示例Job

demo-job.yaml

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: echo
  labels:
    job-name: echo
spec:
  ttlSecondsAfterFinished: 100 # Job在执行结束后(状态为completed或failed)自动清理，设置为0则立即清理，不配置则不会清理
  backoffLimit: 4 # 如果任务执行失败，失败多少次后不再执行
  completions: 5 # 多少个pod执行成功，才认为该Job是成功的
  parallelism: 3 # 并行执行任务的数量
  template:
    metadata:
      labels:
        job-name: echo
    spec:
      restartPolicy: Never
      containers:
        - name: echo
          image: busybox
          imagePullPolicy: IfNotPresent
          command:
            - echo
            - hello job
```

## 2.1 CronJob概念

*CronJob* 创建基于时隔重复调度的 [Jobs](https://kubernetes.io/zh/docs/concepts/workloads/controllers/job/)

一个 CronJob 对象就像 *crontab* (cron table) 文件中的一行。 它用 [Cron](https://en.wikipedia.org/wiki/Cron) 格式进行编写， 并周期性地在给定的调度时间执行 Job。

> **注意：**
>
> 所有 **CronJob** 的 `schedule:` 时间都是基于 [kube-controller-manager](https://kubernetes.io/docs/reference/generated/kube-controller-manager/). 的时区。
>
> 如果你的控制平面在 Pod 或是裸容器中运行了 kube-controller-manager， 那么为该容器所设置的时区将会决定 Cron Job 的控制器所使用的时区。

## 2.2 CronJob资源关键字段

- apiVersion：batch/v1beta1 #1.21+ batch/v1
- spec.schedule：调度周期，和Linux一致，分别是分时日月周
- spec.jobTemplate.spec.template.spec.restartPolicy：重启策略，和Pod一致
- spec.concurrencyPolicy：并发调度策略。可选参数如下
  - Allow：允许同时运行多个任务
  - Forbid：不允许并发运行，如果之前的任务尚未完成，新的任务不会被创建
  - Replace：如果之前的任务尚未完成，新的任务会替换的之前的任务
- spec.suspend：如果设置为true，则暂停后续的任务，默认为false
- spec.successfulJobsHistoryLimit：保留多少已完成的任务，按需配置
- spec.failedJobsHistoryLimit：保留多少失败的任务

## 2.3 示例CronJob

demo-cronjob.yaml

```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: demo-cronjob
  labels:
    run: hello
spec:
  schedule: "*/1 * * * *" # 调度时间，和Linux crontab一致
  concurrencyPolicy: Allow # 并发调度策略，Allow指允许同时允许多个任务
  failedJobsHistoryLimit: 1 # 保留多少失败的任务
  successfulJobsHistoryLimit: 3 # 保留多少已完成的任务
  suspend: false # 如果设置为true，则暂停后续的任务，默认为false
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            run: hello
        spec:
          restartPolicy: OnFailure
          containers:
            - name: hello
              image: busybox
              imagePullPolicy: IfNotPresent
              command:
                - sh
                - -c
                - date;echo Hello from the Kubernetes cluster
```



