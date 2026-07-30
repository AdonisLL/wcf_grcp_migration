using System;
using System.IO;
using System.Runtime.Serialization;
using System.ServiceModel;

namespace Fixtures.DuplexHighRisk
{
    public interface IDispatchCallback
    {
        [OperationContract(IsOneWay = true)]
        void Progress(JobProgress update);
    }

    [ServiceContract(
        Namespace = "urn:fixtures:dispatch:v1",
        CallbackContract = typeof(IDispatchCallback),
        SessionMode = SessionMode.Required)]
    public interface IDispatchService
    {
        [OperationContract(IsInitiating = true, IsTerminating = false, IsOneWay = true)]
        void StartJob(StartJob request);

        [OperationContract(IsInitiating = false, IsTerminating = false)]
        JobProgress GetStatus(string jobId);

        [OperationContract(IsInitiating = false, IsTerminating = true)]
        [TransactionFlow(TransactionFlowOption.Mandatory)]
        void CommitJob(string jobId);
    }

    [ServiceContract(Namespace = "urn:fixtures:archive:v1")]
    public interface IArchiveTransfer
    {
        [OperationContract]
        Stream Download(string archiveId);

        [OperationContract]
        void Upload(Stream content);
    }

    [DataContract]
    public sealed class StartJob
    {
        [DataMember(Order = 1, IsRequired = true)]
        public string JobId { get; set; }

        [DataMember(Order = 2)]
        public byte[] Payload { get; set; }
    }

    [DataContract]
    public sealed class JobProgress
    {
        [DataMember(Order = 1)]
        public string JobId { get; set; }

        [DataMember(Order = 2)]
        public int Percent { get; set; }

        [DataMember(Order = 3)]
        public long Sequence { get; set; }
    }
}
