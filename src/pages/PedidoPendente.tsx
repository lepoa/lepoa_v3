import { useEffect, useState } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import { Clock, Loader2, Package, MessageCircle, RefreshCw, CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Header } from "@/components/Header";
import { supabase } from "@/integrations/supabase/client";

function formatPrice(price: number): string {
  return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(price);
}

const PedidoPendente = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const orderId = searchParams.get("order_id");
  const liveCartId = searchParams.get("live_cart_id");

  const [isLoading, setIsLoading] = useState(true);
  const [order, setOrder] = useState<any>(null);
  const [liveCart, setLiveCart] = useState<any>(null);
  const [retryCount, setRetryCount] = useState(0);

  useEffect(() => {
    if (orderId || liveCartId) {
      loadOrder();
    } else {
      setIsLoading(false);
    }
  }, [orderId, liveCartId]);

  // Auto-retry for live orders (sync may be delayed)
  useEffect(() => {
    if ((liveCartId || orderId) && !order && !isLoading && retryCount < 10) {
      const timer = setTimeout(() => {
        setRetryCount(prev => prev + 1);
        loadOrder();
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [liveCartId, orderId, order, isLoading, retryCount]);

  const loadOrder = async () => {
    try {
      let orderData: any = null;

      if (orderId) {
        const { data } = await supabase
          .from("orders")
          .select("*")
          .eq("id", orderId)
          .single();
        orderData = data;
      } else if (liveCartId) {
        // Try orders table first
        const { data } = await supabase
          .from("orders")
          .select("*")
          .eq("live_cart_id", liveCartId)
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle();
        orderData = data;

        // If no order found, fall back to live_carts directly
        if (!orderData) {
          const { data: cartData } = await supabase
            .from("live_carts")
            .select("*")
            .eq("id", liveCartId)
            .single();

          if (cartData) {
            setLiveCart(cartData);

            // If already paid, try to find the order by other means or redirect
            if (cartData.status === "pago") {
              // Try to find order linked to this user
              const { data: userOrders } = await supabase
                .from("orders")
                .select("id")
                .eq("live_cart_id", liveCartId)
                .limit(1)
                .maybeSingle();

              if (userOrders) {
                navigate(`/meus-pedidos/${userOrders.id}`, { replace: true });
                return;
              }
            }
          }
        }
      }

      if (orderData) {
        setOrder(orderData);

        // If order is already paid, redirect to success
        if (orderData.status === "pago") {
          if (liveCartId) {
            navigate(`/pedido/sucesso?live_cart_id=${liveCartId}`, { replace: true });
          } else {
            navigate(`/pedido/sucesso?order_id=${orderData.id}`, { replace: true });
          }
          return;
        }
      }
    } catch (error) {
      console.error("Error loading order:", error);
    } finally {
      setIsLoading(false);
    }
  };

  const displayOrderId = order?.id || orderId || liveCartId || '';
  const displayName = order?.customer_name || liveCart?.customer_name || "cliente";
  const displayTotal = order?.total || liveCart?.total || 0;
  const hasData = order || liveCart;

  const getWhatsAppUrl = () => {
    const message = encodeURIComponent(
      `Oi! Sou ${displayName}. Tive um problema no pagamento do pedido #${displayOrderId?.slice(0, 8).toUpperCase()}. Pode me ajudar? \u{1F49B}`
    );
    return `https://wa.me/5562991223519?text=${message}`;
  };

  const handleRetryPayment = () => {
    const checkoutUrl = order?.mp_checkout_url || liveCart?.mp_checkout_url;
    if (checkoutUrl) {
      window.open(checkoutUrl, "_blank");
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  // If live cart is paid but we couldn't find the order, show success state
  if (liveCart && liveCart.status === "pago") {
    return (
      <div className="min-h-screen bg-background">
        <Header />
        <main className="container mx-auto px-4 py-12 max-w-lg text-center">
          <div className="w-20 h-20 rounded-full bg-green-100 flex items-center justify-center mx-auto mb-6">
            <CheckCircle2 className="h-10 w-10 text-green-600" />
          </div>
          <h1 className="font-serif text-2xl mb-2">Pagamento confirmado! {"\u{1F389}"}</h1>
          <p className="text-muted-foreground mb-6">
            Seu pedido foi pago com sucesso.
          </p>
          <Card className="mb-6">
            <CardContent className="p-6">
              <div className="flex justify-between items-center mb-4">
                <span className="text-sm text-muted-foreground">Pedido</span>
                <span className="font-mono font-bold text-accent">
                  #{(liveCartId || '').slice(0, 8).toUpperCase()}
                </span>
              </div>
              <div className="flex justify-between font-medium text-lg border-t pt-4">
                <span>Total</span>
                <span className="text-green-600">{formatPrice(displayTotal)}</span>
              </div>
            </CardContent>
          </Card>
          <Button onClick={() => navigate("/conta/meus-pedidos")} className="w-full">
            Ver meus pedidos
          </Button>
        </main>
      </div>
    );
  }

  if (!hasData) {
    return (
      <div className="min-h-screen bg-background">
        <Header />
        <main className="container mx-auto px-4 py-12 max-w-lg text-center">
          <Package className="h-16 w-16 mx-auto text-muted-foreground mb-4" />
          <h1 className="font-serif text-2xl mb-2">Pedido não encontrado</h1>
          <p className="text-sm text-muted-foreground mb-4">Seu pagamento pode estar sendo processado. Aguarde alguns segundos e atualize a página.</p>
          <div className="flex gap-2 justify-center">
            <Button onClick={() => window.location.reload()} variant="outline">Atualizar</Button>
            <Button onClick={() => navigate("/")}>Voltar ao início</Button>
          </div>
        </main>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <Header />

      <main className="container mx-auto px-4 py-12 max-w-lg text-center">
        <div className="w-20 h-20 rounded-full bg-yellow-100 dark:bg-yellow-900/30 flex items-center justify-center mx-auto mb-6 animate-fade-in">
          <Clock className="h-10 w-10 text-yellow-600 dark:text-yellow-400" />
        </div>

        <h1 className="font-serif text-2xl mb-2">Pagamento pendente</h1>
        <p className="text-muted-foreground mb-6">
          Seu pagamento está sendo processado. Assim que for confirmado, você receberá uma notificação.
        </p>

        <Card className="mb-6">
          <CardContent className="p-6">
            <div className="flex justify-between items-center mb-4">
              <span className="text-sm text-muted-foreground">Pedido</span>
              <span className="font-mono font-bold text-accent">
                #{displayOrderId.slice(0, 8).toUpperCase()}
              </span>
            </div>

            <div className="flex justify-between font-medium text-lg border-t pt-4">
              <span>Total</span>
              <span>{formatPrice(displayTotal)}</span>
            </div>
          </CardContent>
        </Card>

        {(order?.mp_checkout_url || liveCart?.mp_checkout_url) && (
          <Button
            onClick={handleRetryPayment}
            className="w-full mb-4"
          >
            <RefreshCw className="h-4 w-4 mr-2" />
            Tentar pagar novamente
          </Button>
        )}

        <a
          href={getWhatsAppUrl()}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center justify-center gap-2 w-full border border-[#25D366] text-[#25D366] hover:bg-[#25D366]/10 font-medium py-3 px-4 rounded-xl transition-colors mb-4"
        >
          <MessageCircle className="h-5 w-5" />
          Falar no WhatsApp
        </a>

        <Button variant="outline" onClick={() => navigate("/conta/meus-pedidos")} className="w-full">
          Ver meus pedidos
        </Button>
      </main>
    </div>
  );
};

export default PedidoPendente;
