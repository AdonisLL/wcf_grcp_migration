using System;
using System.ServiceModel;

namespace Fixtures.FaultsAndSerialization
{
    internal static class Program
    {
        private static void Main()
        {
            using (var host = new ServiceHost(typeof(InvoiceService)))
            {
                host.Open();
                var factory = new ChannelFactory<IInvoiceService>("InvoiceClient");
                var client = factory.CreateChannel();
                try
                {
                    client.GetInvoice(new InvoiceQuery { InvoiceNumber = "" });
                }
                catch (FaultException<ValidationFault> fault)
                {
                    Console.WriteLine(fault.Detail.Code);
                }
                ((IClientChannel)client).Abort();
                factory.Abort();
            }
        }
    }
}
