import { useState } from "react";
import { Star, Crown, Gift, AlertCircle, Loader2, Sparkles, ChevronRight, Lock, Unlock } from "lucide-react";
import { AccountLayout } from "@/components/account/AccountLayout";
import { RewardCard } from "@/components/account/RewardCard";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useLoyalty, LOYALTY_TIERS } from "@/hooks/useLoyalty";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { motion, AnimatePresence } from "framer-motion";

export default function LepoaClub() {
  const {
    loyalty,
    rewards,
    redemptions,
    isLoading,
    getProgressToNextTier,
    canRedeemReward,
    redeemReward,
    getExpiringPoints,
    getTierInfo,
  } = useLoyalty();
  const [redeemingId, setRedeemingId] = useState<string | null>(null);

  const handleRedeem = async (rewardId: string) => {
    setRedeemingId(rewardId);
    try {
      const couponCode = await redeemReward(rewardId);
      if (couponCode) {
        toast.success(`Resgatado! Use o cupom: ${couponCode}`, { duration: 8000 });
      }
    } catch (error: any) {
      toast.error(error.message || "Erro ao resgatar");
    } finally {
      setRedeemingId(null);
    }
  };

  if (isLoading) {
    return (
      <AccountLayout title="Le.Poá Club">
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      </AccountLayout>
    );
  }

  const currentTier = loyalty?.currentTier || "poa";
  const tierInfo = getTierInfo(currentTier);
  const { progress, pointsNeeded, nextTierName } = getProgressToNextTier(
    loyalty?.annualPoints || 0,
    currentTier
  );
  const expiringPoints = getExpiringPoints();
  const featuredRewards = rewards.filter((r) => r.isFeatured);

  // Gradient based on tier
  const getTierGradient = (tier: string) => {
    switch (tier) {
      case "poa_black": return "from-zinc-900 to-black text-white";
      case "poa_platinum": return "from-slate-200 to-slate-400 text-slate-900";
      case "poa_gold": return "from-amber-200 to-amber-500 text-amber-950";
      default: return "from-rose-50 to-rose-200 text-rose-900"; // poa
    }
  };

  return (
    <AccountLayout title="Le.Poá Club" showBackButton>

      {/* Tier Card */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className={cn(
          "relative overflow-hidden rounded-3xl p-8 mb-8 shadow-xl border-none",
          "bg-gradient-to-br",
          getTierGradient(currentTier)
        )}
      >
        {/* Background Elements */}
        <div className="absolute top-0 right-0 p-12 opacity-10">
          <Crown className="w-64 h-64 -mr-16 -mt-16 rotate-12" />
        </div>
        <div className="absolute bottom-0 left-0 w-full h-1/2 bg-gradient-to-t from-black/10 to-transparent" />

        <div className="relative z-10">
          <div className="flex items-center justify-between mb-8">
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center shadow-inner">
                <Crown className="h-8 w-8" />
              </div>
              <div>
                <p className="text-sm font-medium opacity-80 uppercase tracking-wider">Nível Atual</p>
                <h1 className="font-serif text-3xl font-bold tracking-tight">{tierInfo.name}</h1>
              </div>
            </div>
            {nextTierName && (
              <div className="text-right hidden sm:block">
                <p className="text-xs opacity-70 mb-1">Próximo Nível</p>
                <div className="flex items-center gap-2 text-sm font-medium">
                  {nextTierName} <ChevronRight className="w-4 h-4" />
                </div>
              </div>
            )}
          </div>

          <div className="grid grid-cols-2 gap-4 mb-8">
            <div className="bg-white/10 backdrop-blur-md rounded-2xl p-4">
              <p className="text-sm opacity-70 mb-1">Pontos Disponíveis</p>
              <div className="flex items-center gap-2">
                <Star className="w-5 h-5 fill-current" />
                <span className="text-3xl font-bold">{loyalty?.currentPoints || 0}</span>
              </div>
            </div>
            <div className="bg-white/10 backdrop-blur-md rounded-2xl p-4">
              <p className="text-sm opacity-70 mb-1">Pontos por R$ 1</p>
              <div className="flex items-center gap-2">
                <Sparkles className="w-5 h-5" />
                <span className="text-3xl font-bold">{tierInfo.multiplier}x</span>
              </div>
            </div>
          </div>

          {/* Progress Bar */}
          {nextTierName && (
            <div className="relative pt-2">
              <div className="flex justify-between text-xs font-medium mb-2 opacity-90">
                <span>{loyalty?.annualPoints} pontos anuais</span>
                <span>Faltam {pointsNeeded} para {nextTierName}</span>
              </div>
              <div className="h-3 bg-black/20 rounded-full overflow-hidden backdrop-blur-sm">
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${progress}%` }}
                  transition={{ duration: 1.5, ease: "easeOut" }}
                  className="h-full bg-white/90 shadow-[0_0_10px_rgba(255,255,255,0.5)]"
                />
              </div>
            </div>
          )}
        </div>
      </motion.div>

      {/* Tier Benefits */}
      <div className="mb-8">
        <h3 className="font-serif text-lg font-medium mb-4 flex items-center gap-2">
          <Star className="w-5 h-5 text-accent" />
          Benefícios do seu nível
        </h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {tierInfo.benefits.map((benefit, i) => (
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: i * 0.1 }}
              key={i}
              className="flex items-center gap-3 p-4 rounded-xl bg-card border border-border/50 shadow-sm"
            >
              <div className={cn("p-2 rounded-full", currentTier === "poa_black" ? "bg-zinc-100 text-black" : "bg-accent/10 text-accent")}>
                <Unlock className="w-4 h-4" />
              </div>
              <span className="text-sm font-medium">{benefit}</span>
            </motion.div>
          ))}
        </div>
      </div>

      {/* Expiring Points Warning */}
      {expiringPoints > 0 && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: "auto" }}
          className="flex items-center gap-3 p-4 mb-8 bg-amber-50 border border-amber-200 rounded-xl text-amber-800"
        >
          <AlertCircle className="h-5 w-5 shrink-0" />
          <div className="text-sm">
            <span className="font-semibold">{expiringPoints} pontos</span> expiram em 30 dias. Aproveite para resgatar algo especial!
          </div>
        </motion.div>
      )}

      {/* Rewards Tabs */}
      <Tabs defaultValue="rewards" className="w-full">
        <TabsList className="w-full mb-6 p-1 bg-muted/50 rounded-xl">
          <TabsTrigger value="rewards" className="flex-1 rounded-lg">Recompensas</TabsTrigger>
          <TabsTrigger value="my-rewards" className="flex-1 rounded-lg">Meus Resgates</TabsTrigger>
        </TabsList>

        <TabsContent value="rewards" className="space-y-8">
          {/* Featured */}
          {featuredRewards.length > 0 && (
            <section>
              <div className="flex items-center gap-2 mb-4">
                <Sparkles className="h-5 w-5 text-amber-500" />
                <h3 className="font-serif text-lg font-medium">Destaques para você</h3>
              </div>
              <div className="grid grid-cols-2 gap-4">
                {featuredRewards.map((reward) => (
                  <RewardCard
                    key={reward.id}
                    reward={reward}
                    currentPoints={loyalty?.currentPoints || 0}
                    currentTier={currentTier}
                    onRedeem={handleRedeem}
                    isRedeeming={redeemingId === reward.id}
                    canRedeem={canRedeemReward(reward)}
                  />
                ))}
              </div>
            </section>
          )}

          {/* All Rewards */}
          <section>
            <h3 className="font-serif text-lg font-medium mb-4">Todas as recompensas</h3>
            <div className="grid grid-cols-2 gap-4">
              {rewards.map((reward) => (
                <RewardCard
                  key={reward.id}
                  reward={reward}
                  currentPoints={loyalty?.currentPoints || 0}
                  currentTier={currentTier}
                  onRedeem={handleRedeem}
                  isRedeeming={redeemingId === reward.id}
                  canRedeem={canRedeemReward(reward)}
                />
              ))}
            </div>
          </section>
        </TabsContent>

        <TabsContent value="my-rewards">
          {redemptions.length === 0 ? (
            <div className="text-center py-16 bg-muted/30 rounded-3xl border border-dashed">
              <Gift className="h-16 w-16 mx-auto mb-4 text-muted-foreground/30" />
              <h3 className="text-lg font-medium mb-2">Nenhum resgate ainda</h3>
              <p className="text-muted-foreground text-sm max-w-xs mx-auto">
                Seus pontos acumulados podem ser trocados por produtos e descontos incríveis.
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {redemptions.map((r) => (
                <div key={r.id} className="bg-card border rounded-2xl p-5 shadow-sm hover:shadow-md transition-shadow">
                  <div className="flex justify-between items-start">
                    <div>
                      <p className="font-medium text-lg">{r.reward?.name || "Recompensa"}</p>
                      <div className="flex items-center gap-2 mt-2">
                        <div className="bg-muted px-3 py-1 rounded-md font-mono text-sm font-medium select-all">
                          {r.couponCode}
                        </div>
                        <p className="text-xs text-muted-foreground">Copie o código</p>
                      </div>
                    </div>
                    <span className={`text-xs px-3 py-1 rounded-full font-medium ${r.status === "active" ? "bg-green-100 text-green-700" :
                      r.status === "used" ? "bg-gray-100 text-gray-500" :
                        "bg-red-100 text-red-700"
                      }`}>
                      {r.status === "active" ? "Ativo" : r.status === "used" ? "Usado" : "Expirado"}
                    </span>
                  </div>
                  <div className="mt-4 pt-4 border-t flex justify-between items-center text-xs text-muted-foreground">
                    <span>Resgatado em {new Date(r.createdAt).toLocaleDateString("pt-BR")}</span>
                    <span>Válido até {new Date(r.expiresAt).toLocaleDateString("pt-BR")}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </TabsContent>
      </Tabs>
    </AccountLayout>
  );
}
