using System.Collections.Generic;
using System.ServiceModel;

namespace Fixtures.DuplexHighRisk
{
    [ServiceBehavior(
        InstanceContextMode = InstanceContextMode.PerSession,
        ConcurrencyMode = ConcurrencyMode.Reentrant,
        UseSynchronizationContext = false)]
    public sealed class DispatchService : IDispatchService
    {
        private readonly Dictionary<string, JobProgress> _sessionJobs =
            new Dictionary<string, JobProgress>();

        public void StartJob(StartJob request)
        {
            var progress = new JobProgress { JobId = request.JobId, Percent = 0, Sequence = 1 };
            _sessionJobs[request.JobId] = progress;
            OperationContext.Current.GetCallbackChannel<IDispatchCallback>().Progress(progress);
        }

        public JobProgress GetStatus(string jobId)
        {
            return _sessionJobs[jobId];
        }

        [OperationBehavior(TransactionScopeRequired = true, TransactionAutoComplete = false)]
        public void CommitJob(string jobId)
        {
            _sessionJobs[jobId].Percent = 100;
            OperationContext.Current.SetTransactionComplete();
            OperationContext.Current.GetCallbackChannel<IDispatchCallback>()
                .Progress(_sessionJobs[jobId]);
        }
    }
}
