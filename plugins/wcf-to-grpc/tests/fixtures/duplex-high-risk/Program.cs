using System;
using System.ServiceModel;

namespace Fixtures.DuplexHighRisk
{
    internal static class Program
    {
        private static void Main()
        {
            using (var dispatchHost = new ServiceHost(typeof(DispatchService)))
            using (var archiveHost = new ServiceHost(typeof(ArchiveTransferService)))
            {
                dispatchHost.Open();
                archiveHost.Open();
                Console.WriteLine("Fixture hosts are running.");
                Console.ReadLine();
            }
        }
    }
}
