import { useState, useEffect } from "react";
import { useNavigate, Link } from "react-router-dom";
import { Package, ChevronRight } from "lucide-react";
import { Header } from "@/components/Header";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { WhatsAppButton } from "@/components/WhatsAppButton";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { buildWhatsAppLink, buildOrderShortMessage } from "@/lib/whatsappHelpers";
import { getCustomerStatusDisplay } from "@/lib/orderStatusMapping";

interface Order {
  id: string;
  created_at: string;
  status: string;
  total: number;
  customer_name: string;
  tracking_code: string | null;
  items_count?: number;
  type?: 'regular' | 'live'; // Distinguish order source
}

export default function MeusPedidos() {
  const navigate = useNavigate();
  const { user, isLoading: authLoading } = useAuth();
  const [orders, setOrders] = useState<Order[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (!authLoading && !user) {
      navigate("/minha-conta");
    }
  }, [user, authLoading, navigate]);

  useEffect(() => {
    if (user) {
      loadOrders();
    }
  }, [user]);

  const loadOrders = async () => {
    if (!user) return;

    try {
      // 1. Fetch regular orders
      const { data: regularOrders, error: regularError } = await supabase
        .from("orders")
        .select("id, created_at, status, total, customer_name, tracking_code")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false });

      if (regularError) throw regularError;

      // 2. Fetch live shop orders (live_carts linked to user)
      const { data: liveOrders, error: liveError } = await supabase
        .from("live_carts")
        .select("id, created_at, status, total, tracking_code, items:live_cart_items(id)")
        .eq("user_id", user.id)
        .in("status", ["pago", "enviado", "entregue", "aguardando_pagamento", "separacao"]) // filter relevant statuses
        .order("created_at", { ascending: false });

      if (liveError && liveError.code !== "PGRST100") { // ignore if column doesn't exist yet (graceful degradation)
        console.error("Error fetching live orders:", liveError);
      }

      // 3. Process regular orders
      const processedRegularOrders = await Promise.all(
        (regularOrders || []).map(async (order) => {
          const { count } = await supabase
            .from("order_items")
            .select("*", { count: "exact", head: true })
            .eq("order_id", order.id);
          return { ...order, items_count: count || 0, type: 'regular' as const };
        })
      );

      // 4. Process live orders
      const processedLiveOrders: Order[] = (liveOrders || []).map(order => ({
        id: order.id,
        created_at: order.created_at,
        status: order.status,
        total: order.total,
        customer_name: user?.user_metadata?.name || "Cliente",
        tracking_code: order.tracking_code,
        items_count: order.items?.length || 0,
        type: 'live' as const
      }));

      // 5. Combine and Sort
      const allOrders = [...processedRegularOrders, ...processedLiveOrders].sort(
        (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      );

      setOrders(allOrders);
    } catch (error) {
      console.error("Error loading orders:", error);
    } finally {
      setIsLoading(false);
    }
  };

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString("pt-BR", {
      day: "2-digit",
      month: "short",
      year: "numeric",
    });
  };

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("pt-BR", {
      style: "currency",
      currency: "BRL",
    }).format(price);
  };

  if (authLoading) {
    return (
      <div className="min-h-screen bg-background">
        <Header />
        <main className="container mx-auto px-4 py-8">
          <Skeleton className="h-8 w-48 mb-6" />
          <div className="space-y-4">
            {[1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-24 w-full" />
            ))}
          </div>
        </main>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      <Header />

      <main className="container mx-auto px-4 py-8 max-w-2xl">
        <h1 className="font-serif text-2xl mb-6">Meus Pedidos</h1>

        {isLoading ? (
          <div className="space-y-4">
            {[1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-24 w-full" />
            ))}
          </div>
        ) : orders.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center">
              <Package className="h-12 w-12 mx-auto mb-4 text-muted-foreground" />
              <p className="text-muted-foreground mb-4">
                Você ainda não fez nenhum pedido
              </p>
              <Link to="/catalogo" className="text-accent hover:underline">
                Conferir peças →
              </Link>
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-3">
            {orders.map((order) => {
              const status = getCustomerStatusDisplay(order.status, order.tracking_code);
              const StatusIcon = status.icon;
              const orderNumber = order.id.slice(0, 8).toUpperCase();
              const whatsAppUrl = buildWhatsAppLink(buildOrderShortMessage(orderNumber));

              return (
                <Card key={order.id} className="hover:shadow-md transition-shadow">
                  <CardContent className="p-4">
                    <div className="flex items-center justify-between">
                      <Link to={`/meus-pedidos/${order.id}`} className="flex-1">
                        <div className="space-y-1">
                          <div className="flex items-center gap-2">
                            <span className="font-medium text-sm">
                              Pedido #{orderNumber}
                            </span>
                            <Badge className={`${status.color} border-0 gap-1`}>
                              <StatusIcon className="h-3 w-3" />
                              {status.label}
                            </Badge>
                          </div>
                          <p className="text-sm text-muted-foreground">
                            {formatDate(order.created_at)} • {order.items_count} {order.items_count === 1 ? "item" : "itens"}
                          </p>
                          <p className="font-semibold">{formatPrice(order.total)}</p>
                        </div>
                      </Link>
                      <div className="flex items-center gap-2">
                        <WhatsAppButton
                          href={whatsAppUrl}
                          variant="circle"
                        />
                        <Link to={`/meus-pedidos/${order.id}`}>
                          <ChevronRight className="h-5 w-5 text-muted-foreground" />
                        </Link>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        )}
      </main>
    </div>
  );
}
